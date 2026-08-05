#!/usr/bin/env bash

set -uo pipefail

CHECKPOINT="${MIGRATION_CHECKPOINT:-CP-1A}"
CHECKPOINT_EXPLICIT=false
ENV_FILE=""
LEGACY_RUNTIME_MANIFEST="runtime/legacy/runtime-manifest.tsv"
PORTABLE_RUNTIME_MANIFEST="runtime/legacy/portable-runtime-manifest.tsv"
PHASE2_JAVA8_RUNTIME_MANIFEST="runtime/phase2/java8-wildfly9/runtime-manifest.tsv"
PHASE3_JAVA17_RUNTIME_MANIFEST="runtime/phase3/java17-wildfly26/runtime-manifest.tsv"
DB_PROFILE_ARGUMENT=""
DB_PROFILE=""
CI_MODE=false
NON_INTERACTIVE_MODE=false
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/doctor.sh [CHECKPOINT] [--profile PERFIL] [--env ARQUIVO] \
    [--ci|--non-interactive]

Exemplos:
  ./scripts/doctor.sh CP-1A
  ./scripts/doctor.sh CP-1B --env .env
  ./scripts/doctor.sh CP-1D --profile ci-h2 --env .env
  ./scripts/doctor.sh CP-1D --profile oracle --env .env
  ./scripts/doctor.sh CP-3J --profile ci-h2 --env .env

Opções:
  --profile PERFIL  Obrigatório a partir do CP-1D; use ci-h2 ou oracle.
  --env ARQUIVO  Carrega pares simples NOME=VALOR sem executar o arquivo.
  --ci           Modo não interativo; a partir do CP-1D aceita somente ci-h2.
  --non-interactive
                 Ignora identidade Git, autenticação GitHub e containers,
                 que não participam da reprodução local; permite Oracle.
  -h, --help     Mostra esta ajuda.
USAGE
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'OK           %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FALHA        %s\n' "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf 'AVISO        %s\n' "$1"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'NÃO EXIGIDO  %s\n' "$1"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_env_file() {
  local file="$1"
  local line key value line_number=0

  if [[ ! -f "$file" ]]; then
    fail "arquivo de ambiente não encontrado: $file"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      fail "linha $line_number inválida em $file"
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"
    value="$(trim "$value")"

    case "$key" in
      MIGRATION_CHECKPOINT|\
      LAB_BIND_ADDRESS|WILDFLY_HTTP_PORT|WILDFLY_MANAGEMENT_PORT|\
      JAVA7_HOME|JAVA7_ARCHIVE|JAVA7_ARCHIVE_SHA256|JAVA7_TRUSTSTORE|\
      JAVA7_PORTABLE_HOME|JAVA7_PORTABLE_ARCHIVE|JAVA7_PORTABLE_ARCHIVE_SHA256|\
      JAVA8_HOME|JAVA8_ARCHIVE|JAVA8_ARCHIVE_SHA256|\
      JAVA17_HOME|JAVA17_ARCHIVE|JAVA17_ARCHIVE_SHA256|\
      JAVA21_HOME|JAVA21_ARCHIVE|JAVA21_ARCHIVE_SHA256|\
      JAVA25_HOME|JAVA25_ARCHIVE|JAVA25_ARCHIVE_SHA256|\
      MAVEN_HOME|MAVEN_ARCHIVE|MAVEN_ARCHIVE_SHA256|\
      WILDFLY9_HOME|WILDFLY9_ARCHIVE|WILDFLY9_ARCHIVE_SHA256|\
      WILDFLY26_HOME|WILDFLY26_ARCHIVE|WILDFLY26_ARCHIVE_SHA256|\
      WILDFLY41_HOME|WILDFLY41_ARCHIVE|WILDFLY41_ARCHIVE_SHA256|\
      ORACLE_DB_URL|ORACLE_DB_USER|ORACLE_DB_PASSWORD|ORACLE_DB_WALLET|\
      OJDBC7_JAR|OJDBC7_SHA256|OJDBC17_JAR|OJDBC17_SHA256|H2_JAR|H2_SHA256)
        ;;
      *)
        fail "variável não permitida na linha $line_number de $file: $key"
        continue
        ;;
    esac

    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"

  pass "configuração carregada de $file sem executar comandos"
}

checkpoint_rank() {
  case "$1" in
    CP-1A) printf '10' ;;
    CP-1B) printf '11' ;;
    CP-1C) printf '12' ;;
    CP-1D) printf '13' ;;
    CP-1E) printf '14' ;;
    CP-1F) printf '15' ;;
    CP-1G) printf '16' ;;
    CP-2A) printf '20' ;;
    CP-2B) printf '21' ;;
    CP-2C) printf '22' ;;
    CP-2D) printf '23' ;;
    CP-3A) printf '30' ;;
    CP-3B) printf '31' ;;
    CP-3C) printf '32' ;;
    CP-3D) printf '33' ;;
    CP-3E) printf '34' ;;
    CP-3F) printf '35' ;;
    CP-3G) printf '36' ;;
    CP-3H) printf '37' ;;
    CP-3I) printf '38' ;;
    CP-3J) printf '39' ;;
    CP-3K) printf '40' ;;
    *) return 1 ;;
  esac
}

rank_at_least() {
  local minimum
  minimum="$(checkpoint_rank "$1")" || return 1
  (( SELECTED_RANK >= minimum ))
}

require_command() {
  local command_name="$1"
  local label="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "$label disponível"
  else
    fail "$label ausente"
  fi
}

check_required_files() {
  local path
  local required=(
    ".env.example"
    ".gitignore"
    "README.md"
    "CONTRIBUTING.md"
    "SECURITY.md"
    "docs/environment-setup.md"
    "docs/README.md"
    "docs/legacy-application-runbook.md"
    "docs/github-workflow.md"
    "docs/checkpoints.md"
    ".github/pull_request_template.md"
    ".github/workflows/validate.yml"
    "runtime/legacy/runtime-manifest.tsv"
    "scripts/doctor.sh"
    "scripts/validate-repository-baseline.sh"
  )

  if rank_at_least CP-1C; then
    required+=(
      "app/pom.xml"
      "runtime/legacy/war-libraries.txt"
      "scripts/audit-legacy-war.sh"
      "scripts/build-cp-1c.sh"
      "scripts/validate-cp-1c.sh"
    )
  fi

  if rank_at_least CP-1D; then
    required+=(
      "docs/cp-1d-runtime-selection.md"
      "docs/evidence/CP-1D.md"
      "runtime/legacy/portable-runtime-manifest.tsv"
      "scripts/validate-cp-1d-selection.sh"
      "scripts/validate-cp-1d-profiles.sh"
      "scripts/validate-cp-1d-h2.sh"
      "scripts/validate-cp-1d-datasources.sh"
      "scripts/build-cp-1d.sh"
      "scripts/smoke-wildfly9-datasource.sh"
    )
  fi

  if rank_at_least CP-1E; then
    required+=(
      "docs/mybatis-persistence.md"
      "docs/oracle-lab-schema.md"
      "docs/evidence/CP-1E.md"
      "scripts/oracle-lab-schema.sh"
      "scripts/validate-documentation.sh"
      "scripts/validate-cp-1e-persistence.sh"
      "scripts/validate-cp-1e-web.sh"
      "app/src/main/resources/mybatis-config.xml"
      "app/src/main/resources/mybatis/PedidoMapper.xml"
      "app/src/main/resources/mybatis/AnexoMapper.xml"
    )
  fi

  if rank_at_least CP-1F; then
    required+=(
      "docs/evidence/CP-1F.md"
      "docs/legacy-upload.md"
      "docs/legacy-xml-import.md"
      "scripts/validate-cp-1f-upload.sh"
      "scripts/validate-cp-1f-xml.sh"
      "scripts/validate-cp-1f-discovery-logging.sh"
      "scripts/validate-cp-1f-contracts.sh"
      "app/src/main/java/br/com/asillos/migration/persistence/AnexoRepository.java"
      "app/src/main/java/br/com/asillos/migration/web/UploadServlet.java"
      "app/src/main/java/br/com/asillos/migration/integration/xml/LegacyPedidoXmlParser.java"
      "app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java"
      "app/src/main/java/br/com/asillos/migration/integration/validation/ValidatorDiscovery.java"
      "contract-tests/run.sh"
    )
  fi

  if rank_at_least CP-1G; then
    required+=(
      "docs/legacy-baseline-reproduction.md"
      "docs/evidence/CP-1G.md"
      "migration/baselines/01-legacy/README.md"
      "migration/baselines/01-legacy/baseline.properties"
      "migration/baselines/01-legacy/contract-scenarios.tsv"
      "migration/baselines/01-legacy/oracle-persisted-state.tsv"
      "migration/baselines/01-legacy/components.tsv"
      "migration/baselines/01-legacy/maven-dependencies.tsv"
      "migration/incompatibilities.tsv"
      "migration/incompatibility-template.md"
      "scripts/validate-cp-1g-baseline.sh"
    )
  fi

  if rank_at_least CP-2A; then
    required+=(
      "docs/cp-2a-java8-wildfly9.md"
      "docs/evidence/CP-2A.md"
      "runtime/phase2/java8-wildfly9/README.md"
      "runtime/phase2/java8-wildfly9/runtime-manifest.tsv"
      "migration/evidence/CP-2A/before-runtime.properties"
      "migration/evidence/CP-2A/before-build.properties"
      "migration/evidence/CP-2A/after.properties"
      "migration/evidence/CP-2A/contract-ci-h2.json"
      "migration/evidence/CP-2A/contract-oracle.json"
      "migration/steps/CP-2A-java8-toolchain.md"
      "migration/steps/CP-2A-wildfly9-max-perm-size.md"
      "scripts/build-cp-2a.sh"
      "scripts/validate-cp-2a.sh"
    )
  fi

  if rank_at_least CP-2B; then
    required+=(
      "docs/cp-2b-wildfly26.md"
      "docs/evidence/CP-2B.md"
      "runtime/phase2/java8-wildfly26/README.md"
      "runtime/phase2/java8-wildfly26/runtime-manifest.tsv"
      "runtime/phase2/java8-wildfly26/profiles/README.md"
      "runtime/phase2/java8-wildfly26/profiles/ci-h2.cli"
      "runtime/phase2/java8-wildfly26/profiles/oracle.cli"
      "migration/evidence/CP-2B/before-deployment.properties"
      "migration/evidence/CP-2B/compatibility-observations.tsv"
      "migration/evidence/CP-2B/after.properties"
      "migration/evidence/CP-2B/contract-ci-h2.json"
      "migration/evidence/CP-2B/contract-oracle.json"
      "migration/steps/CP-2B-wildfly26-missing-datasource.md"
      "migration/steps/CP-2B-wildfly26-log4j-deprecation.md"
      "migration/steps/CP-2B-wildfly26-default-https.md"
      "migration/steps/CP-2B-wildfly26-pool-name.md"
      "scripts/smoke-wildfly26-datasource.sh"
      "scripts/validate-cp-2b.sh"
    )
  fi

  if rank_at_least CP-2C; then
    required+=(
      ".github/workflows/pr-cache-cleanup.yml"
      "docs/cp-2c-ee8-maven-datasource.md"
      "docs/evidence/CP-2C.md"
      "migration/evidence/CP-2C/after.properties"
      "migration/evidence/CP-2C/contract-ci-h2.json"
      "migration/evidence/CP-2C/contract-oracle.json"
      "migration/evidence/CP-2C/oracle-persistence.json"
      "runtime/portable-runtime-cache.sha256"
      "scripts/build-cp-2c.sh"
      "scripts/qualify-cp-2c-oracle.sh"
      "scripts/ValidateCp2cOraclePersistence.java"
      "scripts/validate-cp-2c-oracle-persistence.sh"
      "scripts/validate-cp-2c.sh"
    )
  fi

  if rank_at_least CP-2D; then
    required+=(
      "docs/evidence/CP-2D.md"
      "docs/phase2-reproduction.md"
      "docs/phase2-real-application-migration-runbook.md"
      "migration/evidence/CP-2D/contract-ci-h2.json"
      "migration/evidence/CP-2D/contract-oracle.json"
      "migration/evidence/CP-2D/oracle-state.json"
      "migration/evidence/CP-2D/oracle-persistence.json"
      "migration/evidence/CP-2D/phase2-comparison.json"
      "migration/evidence/CP-2D/reproduction-oracle.json"
      "migration/baselines/02-java8-wildfly26/README.md"
      "migration/baselines/02-java8-wildfly26/manifest.properties"
      "migration/baselines/02-java8-wildfly26/components.tsv"
      "migration/baselines/02-java8-wildfly26/maven-dependencies.tsv"
      "migration/baselines/02-java8-wildfly26/known-limitations.tsv"
      "scripts/qualify-cp-2d-h2.sh"
      "scripts/qualify-cp-2d-oracle.sh"
      "scripts/ValidatePhase2OracleState.java"
      "scripts/validate-cp-2d-oracle-state.sh"
      "scripts/validate-cp-2d-phase-comparison.sh"
      "scripts/validate-cp-2d-manifest.sh"
      "scripts/validate-cp-2d-real-runbook.sh"
      "scripts/validate-cp-2d-reproduction.sh"
      "scripts/validate-cp-2d-closure.sh"
      "scripts/reproduce-cp-2d.sh"
    )
  fi

  if rank_at_least CP-3A; then
    required+=(
      "docs/evidence/CP-3A.md"
      "migration/evidence/CP-3A/after-build.properties"
      "migration/evidence/CP-3A/before-build.properties"
      "migration/evidence/CP-3A/before-runtime.properties"
      "migration/evidence/CP-3A/contract-after-ci-h2.json"
      "migration/evidence/CP-3A/contract-before-ci-h2.json"
      "migration/evidence/CP-3A/closure.properties"
      "migration/evidence/CP-3A/contract-ci-h2.json"
      "migration/evidence/CP-3A/contract-oracle.json"
      "migration/evidence/CP-3A/oracle-state.json"
      "migration/evidence/CP-3A/oracle-persistence.json"
      "migration/evidence/CP-3A/rollback.properties"
      "migration/steps/CP-3A-java17-bytecode-audit.md"
      "migration/steps/CP-3A-h2-2-check-constraint.md"
      "migration/steps/CP-3A-java17-toolchain.md"
      "runtime/phase3/java17-wildfly26/README.md"
      "runtime/phase3/java17-wildfly26/runtime-manifest.tsv"
      "runtime/phase3/java17-wildfly26/h2/module.xml"
      "runtime/phase3/java17-wildfly26/profiles/README.md"
      "runtime/phase3/java17-wildfly26/profiles/ci-h2.cli"
      "runtime/phase3/java17-wildfly26/profiles/oracle.cli"
      "runtime/portable-runtime-sources.tsv"
      "scripts/build-cp-3a.sh"
      "scripts/prepare-portable-runtime-cache.sh"
      "scripts/qualify-cp-3a-h2.sh"
      "scripts/qualify-cp-3a-oracle.sh"
      "scripts/smoke-cp-3a-datasource.sh"
      "scripts/validate-cp-3a.sh"
    )
  fi

  if rank_at_least CP-3B; then
    required+=(
      "docs/cp-3b-core-dependencies.md"
      "docs/cp-3b-fileupload.md"
      "docs/cp-3b-logging-bridge.md"
      "docs/cp-3b-reflections-bridge.md"
      "docs/evidence/CP-3B.md"
      "app/src/main/webapp/WEB-INF/jboss-deployment-structure.xml"
      "migration/evidence/CP-3B/mybatis-ci-h2.json"
      "migration/evidence/CP-3B/mybatis-oracle.json"
      "migration/evidence/CP-3B/logging-ci-h2.json"
      "migration/evidence/CP-3B/logging-oracle.json"
      "migration/evidence/CP-3B/upload-ci-h2.json"
      "migration/evidence/CP-3B/upload-oracle.json"
      "migration/evidence/CP-3B/discovery-ci-h2.json"
      "migration/evidence/CP-3B/discovery-oracle.json"
      "migration/evidence/CP-3B/closure.properties"
      "migration/steps/CP-3B-commons-fileupload-1.6.0.md"
      "migration/steps/CP-3B-mybatis-3.5.19.md"
      "migration/steps/CP-3B-log4j-over-slf4j.md"
      "migration/steps/CP-3B-reflections-0.10.2.md"
      "runtime/phase3/java17-wildfly26/war-libraries.txt"
      "scripts/build-cp-3b.sh"
      "scripts/qualify-cp-3b-h2.sh"
      "scripts/qualify-cp-3b-oracle.sh"
      "scripts/smoke-cp-3b-datasource.sh"
      "scripts/validate-cp-3b.sh"
    )
  fi

  if rank_at_least CP-3C; then
    required+=(
      "docs/cp-3c-ojdbc17.md"
      "docs/evidence/CP-3C.md"
      "migration/evidence/CP-3C/closure.properties"
      "migration/evidence/CP-3C/rollback.properties"
      "migration/steps/CP-3C-ojdbc17.md"
      "migration/steps/CP-3C-java-xml-apis.md"
      "runtime/phase3/java17-wildfly26/ojdbc17/module.xml.template"
      "runtime/phase3/java17-wildfly26/ojdbc17/register-driver.cli"
      "runtime/phase3/java17-wildfly26/ojdbc17/README.md"
      "scripts/validate-cp-3c-ojdbc17.sh"
      "scripts/validate-cp-3c.sh"
      "scripts/validate-cp-3c-java-xml.sh"
      "scripts/qualify-cp-3c-h2.sh"
      "scripts/qualify-cp-3c-oracle.sh"
      "migration/evidence/CP-3C/ojdbc17-ci-h2.json"
      "migration/evidence/CP-3C/ojdbc17-oracle.json"
    )
  fi

  if rank_at_least CP-3D; then
    required+=(
      "docs/cp-3d-java17-gate.md"
      "docs/cp-3d-reproduction.md"
      "docs/evidence/CP-3D.md"
      "migration/steps/CP-3D-tiles-tld-exception.md"
      "migration/evidence/CP-3D/portable-ci.json"
      "migration/evidence/CP-3D/oracle-qualified.json"
      "migration/evidence/CP-3D/manifest.properties"
      "migration/evidence/CP-3D/closure.properties"
      "migration/evidence/CP-3D/rollback.properties"
      "scripts/qualify-cp-3d-h2.sh"
      "scripts/qualify-cp-3d-oracle.sh"
      "scripts/validate-cp-3d.sh"
      "scripts/validate-cp-3d-tiles-tld.sh"
    )
  fi

  if rank_at_least CP-3E; then
    required+=(
      "docs/cp-3e-entry.md"
      "docs/evidence/CP-3E.md"
      "migration/evidence/CP-3E/compatibility-observations.tsv"
      "migration/evidence/CP-3E/unchanged-war.json"
      "migration/evidence/CP-3E/unchanged-war-server.txt"
      "migration/evidence/CP-3E/jakarta-build.json"
      "migration/evidence/CP-3E/jakarta-build.txt"
      "migration/evidence/CP-3E/closure.properties"
      "migration/steps/CP-3E-wildfly41-entry.md"
      "runtime/phase3/java21-wildfly41/README.md"
      "runtime/phase3/java21-wildfly41/runtime-manifest.tsv"
      "scripts/diagnose-cp-3e-unchanged.sh"
      "scripts/build-cp-3e-jakarta.sh"
      "scripts/validate-cp-3e-entry.sh"
    )
  fi

  if rank_at_least CP-3F; then
    required+=(
      "docs/cp-3f-jakarta-namespaces.md"
      "docs/evidence/CP-3F.md"
      "migration/evidence/CP-3F/jakarta-build.json"
      "migration/evidence/CP-3F/jakarta-build.txt"
      "migration/evidence/CP-3F/tld-historical.xml"
      "migration/evidence/CP-3F/tld-migration.properties"
      "migration/evidence/CP-3F/deployment-tiles-blocked.txt"
      "migration/evidence/CP-3F/contract-ci-h2.json"
      "migration/evidence/CP-3F/contract-oracle.json"
      "migration/evidence/CP-3F/manifest.properties"
      "migration/evidence/CP-3F/closure.properties"
      "migration/evidence/CP-3F/rollback.properties"
      "migration/steps/CP-3F-fileupload-jakarta-linkage.md"
      "migration/steps/CP-3F-oracle-jdbc17-module.md"
      "runtime/phase3/java21-wildfly41/h2/module.xml"
      "runtime/phase3/java21-wildfly41/profiles/ci-h2.cli"
      "scripts/build-cp-3f-jakarta.sh"
      "scripts/rebuild-cp-3f-ide.sh"
      "scripts/validate-cp-3f-namespace.sh"
      "scripts/validate-cp-3f-closure.sh"
    )
  fi

  if rank_at_least CP-3G; then
    required+=(
      "docs/cp-3g-web-substitutions.md"
      "migration/steps/CP-3G-tiles-jsp-layout.md"
      "runtime/phase3/java21-wildfly41/ojdbc17/module.xml.template"
      "runtime/phase3/java21-wildfly41/profiles/oracle.cli"
      "scripts/validate-cp-3g-tiles.sh"
      "scripts/validate-cp-3g-upload.sh"
      "scripts/validate-cp-3g-discovery.sh"
      "scripts/validate-cp-3g-logging.sh"
      "scripts/validate-cp-3g-closure.sh"
      "scripts/smoke-wildfly41-datasource.sh"
      "app/src/main/java/br/com/asillos/migration/integration/validation/ValidatorDiscovery.java"
      "app/src/main/java/br/com/asillos/migration/integration/validation/ValidatorServletContainerInitializer.java"
      "app/src/main/resources/META-INF/services/jakarta.servlet.ServletContainerInitializer"
      "migration/steps/CP-3G-servlet-multipart.md"
      "migration/steps/CP-3G-servlet-container-initializer.md"
      "migration/steps/CP-3G-slf4j-mybatis.md"
      "docs/evidence/CP-3G.md"
      "migration/evidence/CP-3G/discovery-ci-h2.json"
      "migration/evidence/CP-3G/logging-ci-h2.json"
      "migration/evidence/CP-3G/upload-ci-h2.json"
      "migration/evidence/CP-3G/upload-oracle.json"
      "migration/evidence/CP-3G/closure.properties"
      "migration/evidence/CP-3G/rollback.properties"
    )
  fi

  if rank_at_least CP-3H; then
    required+=(
      "migration/steps/CP-3H-xml-safe.md"
      "migration/evidence/CP-3H/xml-ci-h2.json"
      "scripts/validate-cp-3h-xml.sh"
      "migration/steps/CP-3H-ojdbc17-datasource.md"
      "migration/evidence/CP-3H/datasource-ci-h2.json"
      "migration/evidence/CP-3H/datasource-oracle.json"
      "scripts/validate-cp-3h-datasource.sh"
      "migration/steps/CP-3H-oracle-qualification.md"
      "scripts/qualify-cp-3h-oracle.sh"
      "scripts/ValidateCp3hOracleVersion.java"
      "migration/evidence/CP-3H/oracle-qualification.json"
      "scripts/validate-cp-3h-oracle-qualification.sh"
      "migration/steps/CP-3H-final-packaging-audit.md"
      "migration/evidence/CP-3H/packaging-audit.json"
      "scripts/audit-cp-3h-final-packaging.sh"
      "migration/steps/CP-3H-closure.md"
      "docs/evidence/CP-3H.md"
      "migration/evidence/CP-3H/closure-portable-ci.json"
      "migration/evidence/CP-3H/closure-oracle-qualified.json"
      "migration/evidence/CP-3H/closure.properties"
      "migration/evidence/CP-3H/rollback.properties"
      "scripts/validate-cp-3h-closure.sh"
    )
  fi

  if rank_at_least CP-3I; then
    required+=(
      "migration/steps/CP-3I-persistence-semantics.md"
      "docs/evidence/CP-3I.md"
      "migration/evidence/CP-3I/persistence-ci-h2.json"
      "migration/evidence/CP-3I/persistence-oracle.json"
      "scripts/ValidateCp3iPersistence.java"
      "scripts/qualify-cp-3i-persistence.sh"
      "scripts/validate-cp-3i-persistence.sh"
      "migration/steps/CP-3I-contract-comparison.md"
      "migration/evidence/CP-3I/contract-ci-h2.json"
      "migration/evidence/CP-3I/contract-oracle.json"
      "scripts/qualify-cp-3i-contracts.sh"
      "scripts/validate-cp-3i-contracts.sh"
      "migration/steps/CP-3I-manifest.md"
      "migration/evidence/CP-3I/manifest.properties"
      "scripts/generate-cp-3i-manifest.sh"
      "scripts/validate-cp-3i-manifest.sh"
      "docs/cp-3d-reproduction.md"
      "scripts/validate-cp-3i-java17-runbook.sh"
      "migration/steps/CP-3I-closure.md"
      "migration/evidence/CP-3I/closure-portable-ci.json"
      "migration/evidence/CP-3I/closure-oracle-qualified.json"
      "migration/evidence/CP-3I/closure.properties"
      "migration/evidence/CP-3I/rollback.properties"
      "scripts/validate-cp-3i-closure.sh"
    )
  fi

  if rank_at_least CP-3J; then
    required+=(
      "runtime/phase3/java25-wildfly41/README.md"
      "runtime/phase3/java25-wildfly41/runtime-manifest.tsv"
      "docs/evidence/CP-3J.md"
      "migration/evidence/CP-3J/runtime-selection.properties"
      "migration/evidence/CP-3J/java25-build-expected.properties"
      "scripts/validate-cp-3j-runtime-selection.sh"
      "scripts/build-cp-3j-java25.sh"
      "scripts/validate-cp-3j-java25.sh"
    )
  fi

  if rank_at_least CP-3K; then
    required+=(
      "migration/incompatibility-catalog.md"
      "migration/incompatibility-fixtures.tsv"
      "scripts/validate-incompatibility-catalog.sh"
      "docs/cp-3k-reproduction.md"
      "docs/evidence/CP-3K.md"
      "scripts/reproduce-cp-3k.sh"
      "scripts/validate-cp-3k-reproduction.sh"
    )
  fi

  for path in "${required[@]}"; do
    if [[ -f "$path" ]]; then
      pass "arquivo obrigatório presente: $path"
    else
      fail "arquivo obrigatório ausente: $path"
    fi
  done
}

check_repository() {
  require_command git "Git"

  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "diretório é um worktree Git"
  else
    fail "diretório não é um worktree Git"
    return
  fi

  if git check-ignore -q .env 2>/dev/null; then
    pass ".env está ignorado"
  else
    fail ".env não está ignorado"
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    pass "remote origin configurado sem expor sua URL"
  else
    fail "remote origin não configurado"
  fi

  if [[ "$CI_MODE" == true || "$NON_INTERACTIVE_MODE" == true ]]; then
    skip "identidade Git local (execução não interativa)"
    skip "autenticação interativa da GitHub CLI (execução não interativa)"
  else
    if [[ -n "$(git config --get user.name 2>/dev/null || true)" ]]; then
      pass "user.name do Git configurado"
    else
      fail "user.name do Git não configurado"
    fi

    if [[ -n "$(git config --get user.email 2>/dev/null || true)" ]]; then
      pass "user.email do Git configurado"
    else
      fail "user.email do Git não configurado"
    fi

    require_command gh "GitHub CLI"
    if command -v gh >/dev/null 2>&1; then
      if gh auth status --hostname github.com >/dev/null 2>&1; then
        pass "GitHub CLI autenticada em github.com"
      else
        fail "GitHub CLI sem autenticação válida em github.com"
      fi
    fi
  fi
}

check_sensitive_paths() {
  local found=""
  local tracked=""

  found="$(
    find . -path './.git' -prune -o -type f \
      \( -name '*.pem' -o -name '*.key' -o \
         -name '*.p12' -o -name '*.pfx' -o -name '*.jks' -o \
         -name '*.wallet' -o -name 'ojdbc*.jar' -o \
         -name 'h2-*.jar' -o -name 'jdk-7u80*' -o \
         -name 'zulu7*-jdk7*-linux_x64.tar.gz' \) -print -quit
  )"

  if [[ -z "$found" ]]; then
    pass "nenhum arquivo local sensível conhecido encontrado"
  else
    fail "arquivo local sensível encontrado; remova-o do checkout"
  fi

  if command -v git >/dev/null 2>&1 &&
     git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked="$(
      git ls-files | awk '
        /(^|\/)\.env$/ ||
        /\.(pem|key|p12|pfx|jks|wallet)$/ ||
        /(^|\/)ojdbc[^/]*\.jar$/ ||
        /(^|\/)h2-[^/]*\.jar$/ ||
        /(^|\/)jdk-7u80/ ||
        /(^|\/)zulu7[^/]*-jdk7[^/]*-linux_x64\.tar\.gz$/ ||
        /(^|\/)\.secrets\// ||
        /(^|\/)oracle-wallet\// { print; exit }
      '
    )"
    if [[ -z "$tracked" ]]; then
      pass "nenhum caminho sensível conhecido está versionado"
    else
      fail "há caminho sensível versionado; inspecione git ls-files"
    fi
  fi
}

check_container_runtime() {
  if command -v docker >/dev/null 2>&1; then
    pass "Docker CLI disponível"
    if docker info >/dev/null 2>&1; then
      pass "Docker daemon acessível"
    else
      fail "Docker daemon não está acessível"
    fi
  elif command -v podman >/dev/null 2>&1; then
    warn "Podman disponível; o checkpoint deve confirmar suporte explícito"
    if podman info >/dev/null 2>&1; then
      pass "Podman runtime acessível"
    else
      fail "Podman runtime não está acessível"
    fi
  else
    fail "nenhum runtime de containers suportado foi encontrado"
  fi
}

check_java() {
  local label="$1"
  local home_variable="$2"
  local expected_pattern="$3"
  local archive_variable="$4"
  local checksum_variable="$5"
  local manifest_component="${6:-}"
  local java_home="${!home_variable:-}"
  local output=""

  if [[ -z "$java_home" ]]; then
    fail "$label: $home_variable não definido"
  elif [[ ! -x "$java_home/bin/java" ]]; then
    fail "$label: executável bin/java ausente no diretório configurado"
  else
    output="$("$java_home/bin/java" -version 2>&1 | head -n 1 || true)"
    if [[ "$output" == *"$expected_pattern"* ]]; then
      pass "$label: versão esperada detectada"
    else
      fail "$label: versão detectada não corresponde a $expected_pattern"
    fi
  fi

  if [[ -n "$manifest_component" ]]; then
    check_manifest_archive "$manifest_component" "$label" \
      "$archive_variable" "$checksum_variable"
  else
    check_archive_checksum "$label" "$archive_variable" "$checksum_variable"
  fi
}

manifest_field() {
  local component="$1"
  local field="$2"

  awk -F '\t' -v wanted_component="$component" -v wanted_field="$field" '
    NR == 1 {
      for (column = 1; column <= NF; column++) {
        header[$column] = column
      }
      next
    }
    $1 == wanted_component {
      if (!(wanted_field in header)) {
        exit 2
      }
      print $header[wanted_field]
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$LEGACY_RUNTIME_MANIFEST"
}

portable_manifest_field() {
  local component="$1"
  local field="$2"

  awk -F '\t' -v wanted_component="$component" -v wanted_field="$field" '
    NR == 1 {
      for (column = 1; column <= NF; column++) {
        header[$column] = column
      }
      next
    }
    $1 == wanted_component {
      if (!(wanted_field in header)) {
        exit 2
      }
      print $header[wanted_field]
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$PORTABLE_RUNTIME_MANIFEST"
}

phase2_java8_manifest_field() {
  local field="$1"

  awk -F '\t' -v wanted_field="$field" '
    NR == 1 {
      for (column = 1; column <= NF; column++) {
        header[$column] = column
      }
      next
    }
    $1 == "temurin-openjdk" {
      if (!(wanted_field in header)) {
        exit 2
      }
      print $header[wanted_field]
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$PHASE2_JAVA8_RUNTIME_MANIFEST"
}

phase3_manifest_field() {
  local component="$1"
  local field="$2"

  awk -F '\t' -v wanted_component="$component" -v wanted_field="$field" '
    NR == 1 {
      for (column = 1; column <= NF; column++) {
        header[$column] = column
      }
      next
    }
    $1 == wanted_component {
      if (!(wanted_field in header)) {
        exit 2
      }
      print $header[wanted_field]
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$PHASE3_JAVA17_RUNTIME_MANIFEST"
}

check_phase3_artifact() {
  local component="$1"
  local label="$2"
  local artifact_variable="$3"
  local checksum_variable="$4"
  local artifact="${!artifact_variable:-}"
  local configured_checksum="${!checksum_variable:-}"
  local expected_artifact=""
  local expected_checksum=""
  local origin=""
  local license=""
  local actual=""

  if [[ ! -f "$PHASE3_JAVA17_RUNTIME_MANIFEST" ]]; then
    fail "$label: manifesto do gate Java 17 ausente"
    return
  fi

  expected_artifact="$(
    phase3_manifest_field "$component" archive 2>/dev/null || true
  )"
  expected_checksum="$(
    phase3_manifest_field "$component" sha256 2>/dev/null || true
  )"
  origin="$(
    phase3_manifest_field "$component" origin 2>/dev/null || true
  )"
  license="$(
    phase3_manifest_field "$component" license 2>/dev/null || true
  )"

  if [[ -z "$expected_artifact" || -z "$origin" || -z "$license" ||
        ! "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "$label: identidade ou proveniência incompleta no manifesto Java 17"
    return
  fi
  if [[ -z "$artifact" || ! -f "$artifact" ]]; then
    fail "$label: $artifact_variable não aponta para o arquivo externo"
    return
  fi
  if [[ "$(basename "$artifact")" != "$expected_artifact" ]]; then
    fail "$label: nome do arquivo diverge do manifesto Java 17"
    return
  fi
  if [[ "${configured_checksum,,}" != "${expected_checksum,,}" ]]; then
    fail "$label: $checksum_variable diverge do manifesto Java 17"
    return
  fi

  actual="$(sha256sum "$artifact" | awk '{print $1}')"
  if [[ "$actual" != "$expected_checksum" ]]; then
    fail "$label: checksum efetivo diverge do manifesto Java 17"
    return
  fi

  pass "$label: origem aprovada $origin"
  pass "$label: licença registrada $license"
  pass "$label: checksum SHA-256 efetivo $actual"
}

check_phase3_java17() {
  local java_home="${JAVA17_HOME:-}"
  local version_output=""

  if [[ -z "$java_home" || ! -x "$java_home/bin/java" ]]; then
    fail "Temurin Java 17: JAVA17_HOME não aponta para um JDK"
  else
    version_output="$("$java_home/bin/java" -version 2>&1 || true)"
    if [[ "$version_output" == *'openjdk version "17.0.20"'* &&
          "$version_output" == *'Temurin-17.0.20+8'* ]]; then
      pass "Temurin Java 17: OpenJDK 17.0.20+8 detectado"
    else
      fail "Temurin Java 17: distribuição ou build divergente"
    fi
  fi

  check_phase3_artifact temurin-openjdk "Temurin Java 17" \
    JAVA17_ARCHIVE JAVA17_ARCHIVE_SHA256
}

check_phase2_java8() {
  local java_home="${JAVA8_HOME:-}"
  local archive="${JAVA8_ARCHIVE:-}"
  local configured_checksum="${JAVA8_ARCHIVE_SHA256:-}"
  local expected_archive=""
  local expected_checksum=""
  local origin=""
  local license=""
  local lifecycle=""
  local scope=""
  local version_output=""
  local actual_checksum=""

  if [[ ! -f "$PHASE2_JAVA8_RUNTIME_MANIFEST" ]]; then
    fail "Temurin Java 8: manifesto CP-2A ausente"
    return
  fi

  expected_archive="$(
    phase2_java8_manifest_field archive 2>/dev/null || true
  )"
  expected_checksum="$(
    phase2_java8_manifest_field sha256 2>/dev/null || true
  )"
  origin="$(phase2_java8_manifest_field origin 2>/dev/null || true)"
  license="$(phase2_java8_manifest_field license 2>/dev/null || true)"
  lifecycle="$(
    phase2_java8_manifest_field lifecycle 2>/dev/null || true
  )"
  scope="$(phase2_java8_manifest_field scope 2>/dev/null || true)"

  if [[ -z "$origin" || -z "$license" ||
        "$lifecycle" != "maintained-by-Eclipse-Temurin" ||
        "$scope" != "CP-2A-and-CP-2B" ]]; then
    fail "Temurin Java 8: proveniência incompleta no manifesto CP-2A"
  else
    pass "Temurin Java 8: origem aprovada $origin"
    pass "Temurin Java 8: licença registrada $license"
  fi

  if [[ -z "$java_home" || ! -x "$java_home/bin/java" ]]; then
    fail "Temurin Java 8: JAVA8_HOME não aponta para um JDK"
  else
    version_output="$("$java_home/bin/java" -version 2>&1 || true)"
    if [[ "$version_output" == *'openjdk version "1.8.0_492"'* &&
          "$version_output" == *"(Temurin)"* ]]; then
      pass "Temurin Java 8: OpenJDK 8u492-b09 detectado"
    else
      fail "Temurin Java 8: distribuição ou build divergente"
    fi
  fi

  if [[ -z "$archive" || ! -f "$archive" ]]; then
    fail "Temurin Java 8: JAVA8_ARCHIVE não encontrado"
    return
  fi
  if [[ "$(basename "$archive")" != "$expected_archive" ]]; then
    fail "Temurin Java 8: nome do arquivo diverge do manifesto CP-2A"
    return
  fi
  if [[ "${configured_checksum,,}" != "${expected_checksum,,}" ]]; then
    fail "Temurin Java 8: JAVA8_ARCHIVE_SHA256 diverge do manifesto CP-2A"
    return
  fi
  actual_checksum="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "$actual_checksum" == "$expected_checksum" ]]; then
    pass "Temurin Java 8: checksum SHA-256 efetivo $actual_checksum"
  else
    fail "Temurin Java 8: checksum efetivo diverge do manifesto CP-2A"
  fi
}

check_portable_artifact() {
  local component="$1"
  local label="$2"
  local artifact_variable="$3"
  local checksum_variable="$4"
  local artifact="${!artifact_variable:-}"
  local configured_checksum="${!checksum_variable:-}"
  local expected_artifact=""
  local expected_checksum=""
  local origin=""
  local license=""
  local lifecycle=""
  local scope=""
  local actual=""

  if [[ ! -f "$PORTABLE_RUNTIME_MANIFEST" ]]; then
    fail "$label: manifesto portátil ausente"
    return
  fi

  expected_artifact="$(
    portable_manifest_field "$component" artifact 2>/dev/null || true
  )"
  expected_checksum="$(
    portable_manifest_field "$component" sha256 2>/dev/null || true
  )"
  origin="$(portable_manifest_field "$component" origin 2>/dev/null || true)"
  license="$(portable_manifest_field "$component" license 2>/dev/null || true)"
  lifecycle="$(
    portable_manifest_field "$component" lifecycle 2>/dev/null || true
  )"
  scope="$(portable_manifest_field "$component" scope 2>/dev/null || true)"

  if [[ -z "$expected_artifact" || -z "$origin" || -z "$license" ||
        "$lifecycle" != "EOL" || "$scope" != "portable-ci" ]]; then
    fail "$label: registro incompleto no manifesto portátil"
    return
  fi
  if [[ ! "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "$label: checksum inválido no manifesto portátil"
    return
  fi
  if [[ -n "$configured_checksum" &&
        "${configured_checksum,,}" != "${expected_checksum,,}" ]]; then
    fail "$label: $checksum_variable diverge do manifesto portátil"
    return
  fi
  if [[ -z "$artifact" ]]; then
    fail "$label: $artifact_variable não definido"
    return
  fi
  if [[ ! -f "$artifact" ]]; then
    fail "$label: artefato externo não encontrado"
    return
  fi
  if [[ "$(basename "$artifact")" != "$expected_artifact" ]]; then
    fail "$label: nome do artefato diverge do manifesto portátil"
    return
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    fail "$label: sha256sum ausente"
    return
  fi

  actual="$(sha256sum "$artifact" | awk '{print $1}')"
  if [[ "${actual,,}" != "${expected_checksum,,}" ]]; then
    fail "$label: checksum SHA-256 diverge do manifesto portátil"
    return
  fi

  pass "$label: origem aprovada $origin"
  pass "$label: licença registrada $license"
  pass "$label: lifecycle EOL e escopo portable-ci registrados"
  pass "$label: checksum SHA-256 efetivo $actual"
}

check_portable_java7() {
  local java_home="${JAVA7_PORTABLE_HOME:-}"
  local output=""

  if [[ -z "$java_home" ]]; then
    fail "Zulu Java 7 portátil: JAVA7_PORTABLE_HOME não definido"
  elif [[ ! -x "$java_home/bin/java" ]]; then
    fail "Zulu Java 7 portátil: executável bin/java ausente"
  else
    output="$("$java_home/bin/java" -version 2>&1 || true)"
    if [[ "$output" == *'openjdk version "1.7.0_352"'* &&
          "$output" == *"Zulu 7.56.0.11-CA"* ]]; then
      pass "Zulu Java 7 portátil: build 7.56.0.11 CA / 1.7.0_352 detectada"
    else
      fail "Zulu Java 7 portátil: build aprovada não detectada"
    fi
  fi

  check_portable_artifact zulu-openjdk "Zulu Java 7 portátil" \
    JAVA7_PORTABLE_ARCHIVE JAVA7_PORTABLE_ARCHIVE_SHA256
}

check_h2() {
  local driver="${H2_JAR:-}"
  local java_home="${JAVA7_PORTABLE_HOME:-}"
  local expected_version="1.4.200"
  local output=""

  if rank_at_least CP-3A; then
    java_home="${JAVA17_HOME:-}"
    expected_version="2.4.240"
    check_phase3_artifact h2 "H2 portátil" H2_JAR H2_SHA256
  elif rank_at_least CP-2A; then
    java_home="${JAVA8_HOME:-}"
    check_portable_artifact h2 "H2 portátil" H2_JAR H2_SHA256
  else
    check_portable_artifact h2 "H2 portátil" H2_JAR H2_SHA256
  fi

  if [[ -z "$driver" || ! -f "$driver" ]]; then
    return
  fi
  if [[ -z "$java_home" || ! -x "$java_home/bin/java" ]]; then
    fail "H2 portátil: Java portátil indisponível para o smoke"
    return
  fi

  output="$(
    "$java_home/bin/java" -cp "$driver" org.h2.tools.Shell \
      -url 'jdbc:h2:mem:doctor;MODE=Oracle;DB_CLOSE_DELAY=-1' \
      -user sa -password '' -sql 'SELECT H2VERSION();' 2>&1 || true
  )"
  if [[ "$output" == *"$expected_version"* && "$output" == *"(1 row"* ]]; then
    pass "H2 portátil: versão $expected_version iniciou em memória no modo Oracle"
  else
    fail "H2 portátil: smoke em memória no modo Oracle falhou"
  fi
}

check_manifest_archive() {
  local component="$1"
  local label="$2"
  local archive_variable="$3"
  local checksum_variable="$4"
  local archive="${!archive_variable:-}"
  local configured_checksum="${!checksum_variable:-}"
  local expected_archive=""
  local expected_checksum=""
  local origin=""
  local license=""
  local actual=""

  if [[ ! -f "$LEGACY_RUNTIME_MANIFEST" ]]; then
    fail "$label: manifesto legado ausente"
    return
  fi

  expected_archive="$(manifest_field "$component" archive 2>/dev/null || true)"
  expected_checksum="$(manifest_field "$component" sha256 2>/dev/null || true)"
  origin="$(manifest_field "$component" origin 2>/dev/null || true)"
  license="$(manifest_field "$component" license 2>/dev/null || true)"

  if [[ -z "$expected_archive" || -z "$origin" || -z "$license" ]]; then
    fail "$label: registro incompleto no manifesto legado"
    return
  fi

  if [[ ! "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "$label: checksum ainda não aprovado no manifesto legado"
    return
  fi

  if [[ -n "$configured_checksum" ]] &&
     [[ "${configured_checksum,,}" != "${expected_checksum,,}" ]]; then
    fail "$label: $checksum_variable diverge do manifesto legado"
    return
  fi

  if [[ -z "$archive" ]]; then
    fail "$label: $archive_variable não definido"
    return
  fi
  if [[ ! -f "$archive" ]]; then
    fail "$label: arquivo externo não encontrado"
    return
  fi
  if [[ "$(basename "$archive")" != "$expected_archive" ]]; then
    fail "$label: nome do arquivo diverge do manifesto legado"
    return
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    fail "$label: sha256sum ausente"
    return
  fi

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "${actual,,}" != "${expected_checksum,,}" ]]; then
    fail "$label: checksum SHA-256 diverge do manifesto legado"
    return
  fi

  pass "$label: origem aprovada $origin"
  pass "$label: licença registrada $license"
  pass "$label: checksum SHA-256 efetivo $actual"
}

check_archive_checksum() {
  local label="$1"
  local archive_variable="$2"
  local checksum_variable="$3"
  local archive="${!archive_variable:-}"
  local expected="${!checksum_variable:-}"
  local actual=""

  if [[ -z "$archive" ]]; then
    fail "$label: $archive_variable não definido"
    return
  fi
  if [[ ! -f "$archive" ]]; then
    fail "$label: arquivo externo não encontrado"
    return
  fi
  if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "$label: $checksum_variable deve conter SHA-256 com 64 caracteres"
    return
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    fail "$label: sha256sum ausente"
    return
  fi

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "${actual,,}" == "${expected,,}" ]]; then
    pass "$label: checksum SHA-256 aprovado"
  else
    fail "$label: checksum SHA-256 divergente"
  fi
}

check_wildfly() {
  local label="$1"
  local home_variable="$2"
  local expected_version="$3"
  local archive_variable="$4"
  local checksum_variable="$5"
  local manifest_component="${6:-}"
  local wildfly_home="${!home_variable:-}"
  local manifest=""

  if [[ -z "$wildfly_home" ]]; then
    fail "$label: $home_variable não definido"
  elif [[ ! -x "$wildfly_home/bin/standalone.sh" ]]; then
    fail "$label: bin/standalone.sh ausente no diretório configurado"
  else
    manifest="$(
      find "$wildfly_home/modules" -path '*/org/jboss/as/product/*/dir/META-INF/MANIFEST.MF' \
        -type f -print -quit 2>/dev/null
    )"
    if [[ -n "$manifest" ]] && grep -Fq "$expected_version" "$manifest"; then
      pass "$label: versão $expected_version detectada no manifesto"
    elif [[ -f "$wildfly_home/version.txt" ]] &&
         grep -Fq "$expected_version" "$wildfly_home/version.txt"; then
      pass "$label: versão $expected_version detectada em version.txt"
    else
      fail "$label: não foi possível confirmar a versão $expected_version"
    fi
  fi

  if [[ -n "$manifest_component" ]]; then
    check_manifest_archive "$manifest_component" "$label" \
      "$archive_variable" "$checksum_variable"
  else
    check_archive_checksum "$label" "$archive_variable" "$checksum_variable"
  fi
}

check_legacy_maven() {
  local java_home_variable="$1"
  local expected_java_version="$2"
  local java_label="$3"
  local maven_home="${MAVEN_HOME:-}"
  local java_home="${!java_home_variable:-}"
  local maven_command=""
  local output=""

  if [[ -z "$maven_home" ]]; then
    fail "Maven legado: MAVEN_HOME não definido"
  elif [[ ! -x "$maven_home/bin/mvn" ]]; then
    fail "Maven legado: executável bin/mvn ausente no diretório configurado"
  else
    maven_command="$maven_home/bin/mvn"
    output="$(
      JAVA_HOME="$java_home" PATH="$java_home/bin:$PATH" \
        "$maven_command" --version 2>&1 || true
    )"

    if [[ "$output" == *"Apache Maven 3.8.9"* ]]; then
      pass "Maven legado: versão 3.8.9 detectada"
    else
      fail "Maven legado: versão 3.8.9 não detectada"
    fi

    if [[ "$output" == *"Java version: $expected_java_version"* ]]; then
      pass "Maven legado: execução efetiva com $java_label"
    else
      fail "Maven legado: não executou com $java_label"
    fi
  fi

  check_manifest_archive apache-maven "Maven legado" \
    MAVEN_ARCHIVE MAVEN_ARCHIVE_SHA256
}

check_java7_truststore() {
  local truststore="${JAVA7_TRUSTSTORE:-}"
  local java_home="${JAVA7_HOME:-}"

  if [[ -z "$truststore" ]]; then
    fail "Java 7: JAVA7_TRUSTSTORE não definido"
    return
  fi
  if [[ ! -f "$truststore" ]]; then
    fail "Java 7: truststore atualizado não encontrado"
    return
  fi
  if [[ ! -x "$java_home/bin/keytool" ]]; then
    fail "Java 7: keytool ausente no JDK configurado"
    return
  fi
  if "$java_home/bin/keytool" -list -keystore "$truststore" \
      -storepass changeit >/dev/null 2>&1; then
    pass "Java 7: truststore JKS atualizado legível"
  else
    fail "Java 7: truststore não é legível pelo keytool legado"
  fi
}

check_ojdbc7() {
  local driver="${OJDBC7_JAR:-}"
  local expected="${OJDBC7_SHA256:-}"
  local actual=""
  local frozen=""

  if [[ -z "$driver" ]]; then
    fail "Oracle JDBC: OJDBC7_JAR não definido"
    return
  fi
  if [[ ! -f "$driver" ]]; then
    fail "Oracle JDBC: arquivo externo não encontrado"
    return
  fi
  if [[ "$(basename "$driver")" != "ojdbc7.jar" ]]; then
    fail "Oracle JDBC: o arquivo externo deve se chamar ojdbc7.jar"
    return
  fi
  if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "Oracle JDBC: OJDBC7_SHA256 deve conter 64 caracteres"
    return
  fi

  if rank_at_least CP-1G; then
    frozen="$(
      awk -F '\t' '
        NR > 1 && $1 == "ojdbc7" {
          print $5
          found = 1
          exit
        }
        END {
          if (!found) {
            exit 1
          }
        }
      ' migration/baselines/01-legacy/components.tsv 2>/dev/null || true
    )"
    if [[ ! "$frozen" =~ ^[[:xdigit:]]{64}$ ]] ||
       [[ "${expected,,}" != "${frozen,,}" ]]; then
      fail "Oracle JDBC: checksum diverge do baseline congelado"
      return
    fi
  fi

  actual="$(sha256sum "$driver" | awk '{print $1}')"
  if [[ "${actual,,}" == "${expected,,}" ]]; then
    pass "Oracle JDBC: ojdbc7 externo aprovado por SHA-256"
  else
    fail "Oracle JDBC: checksum do ojdbc7 diverge"
  fi
}

check_ojdbc17() {
  local driver="${OJDBC17_JAR:-}"
  local expected="${OJDBC17_SHA256:-}"
  local actual=""
  local frozen=""

  if [[ -z "$driver" ]]; then
    fail "Oracle JDBC: OJDBC17_JAR não definido"
    return
  fi
  if [[ ! -f "$driver" ]]; then
    fail "Oracle JDBC: arquivo externo ojdbc17 não encontrado"
    return
  fi
  if [[ "$(basename "$driver")" != "ojdbc17.jar" ]]; then
    fail "Oracle JDBC: o arquivo externo deve se chamar ojdbc17.jar"
    return
  fi
  if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "Oracle JDBC: OJDBC17_SHA256 deve conter 64 caracteres"
    return
  fi

  frozen="$({
    awk -F '\t' '
      NR > 1 && $1 == "ojdbc17" {
        print $6
        found = 1
        exit
      }
      END {
        if (!found) {
          exit 1
        }
      }
    ' runtime/phase3/java17-wildfly26/runtime-manifest.tsv
  } 2>/dev/null || true)"
  if [[ ! "$frozen" =~ ^[[:xdigit:]]{64}$ ]] ||
     [[ "${expected,,}" != "${frozen,,}" ]]; then
    fail "Oracle JDBC: checksum do ojdbc17 diverge do manifesto CP-3C"
    return
  fi

  actual="$(sha256sum "$driver" | awk '{print $1}')"
  if [[ "${actual,,}" == "${expected,,}" ]]; then
    pass "Oracle JDBC: ojdbc17 23.26.2.0.0 externo aprovado por SHA-256"
  else
    fail "Oracle JDBC: checksum do ojdbc17 diverge"
  fi
}

check_modern_maven() {
  local maven_command="mvn"
  local output=""

  if [[ -n "${MAVEN_HOME:-}" ]]; then
    maven_command="$MAVEN_HOME/bin/mvn"
  fi

  if [[ ! -x "$maven_command" ]] && ! command -v "$maven_command" >/dev/null 2>&1; then
    fail "Maven: executável não encontrado"
    return
  fi

  output="$("$maven_command" --version 2>/dev/null | head -n 1 || true)"
  if [[ "$output" == *"Apache Maven 3.9.16"* ]]; then
    pass "Maven 3.9.16 detectado"
  else
    fail "Maven 3.9.16 não detectado"
  fi
}

check_oracle_variables() {
  local variable
  local required=(ORACLE_DB_URL ORACLE_DB_USER ORACLE_DB_PASSWORD)

  for variable in "${required[@]}"; do
    if [[ -n "${!variable:-}" ]]; then
      pass "$variable presente (valor oculto)"
    else
      fail "$variable ausente"
    fi
  done

  if [[ -n "${ORACLE_DB_WALLET:-}" ]]; then
    if [[ -e "$ORACLE_DB_WALLET" ]]; then
      pass "ORACLE_DB_WALLET presente e caminho acessível"
    else
      fail "ORACLE_DB_WALLET definido, mas caminho não está acessível"
    fi
  else
    skip "ORACLE_DB_WALLET não configurado; opcional quando a conexão não usa wallet"
  fi
}

check_network_defaults() {
  local bind_address="${LAB_BIND_ADDRESS:-127.0.0.1}"
  local port

  case "$bind_address" in
    127.0.0.1|localhost|::1)
      pass "bind de laboratório restrito a loopback"
      ;;
    *)
      fail "LAB_BIND_ADDRESS deve permanecer em loopback para os runtimes legados"
      ;;
  esac

  for port in "${WILDFLY_HTTP_PORT:-8080}" "${WILDFLY_MANAGEMENT_PORT:-9990}"; do
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
      pass "porta configurada é válida: $port"
    else
      fail "porta configurada fora do intervalo TCP válido"
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      if [[ $# -lt 2 ]]; then
        printf 'FALHA        --env exige um arquivo\n'
        exit 2
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    --profile)
      if [[ $# -lt 2 ]]; then
        printf 'FALHA        --profile exige ci-h2 ou oracle\n'
        exit 2
      fi
      DB_PROFILE_ARGUMENT="$2"
      shift 2
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'FALHA        opção desconhecida: %s\n' "$1"
      usage
      exit 2
      ;;
    *)
      CHECKPOINT="$1"
      CHECKPOINT_EXPLICIT=true
      shift
      ;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  load_env_file "$ENV_FILE"
fi

if [[ "$CHECKPOINT_EXPLICIT" == false ]]; then
  CHECKPOINT="${MIGRATION_CHECKPOINT:-$CHECKPOINT}"
fi

if ! SELECTED_RANK="$(checkpoint_rank "$CHECKPOINT")"; then
  printf 'FALHA        checkpoint inválido: %s\n' "$CHECKPOINT"
  usage
  exit 2
fi

if rank_at_least CP-1D && [[ -z "$DB_PROFILE_ARGUMENT" ]]; then
  printf 'FALHA        --profile é obrigatório a partir do CP-1D; use ci-h2 ou oracle\n'
  exit 2
fi

DB_PROFILE="${DB_PROFILE_ARGUMENT:-ci-h2}"

case "$DB_PROFILE" in
  ci-h2|oracle)
    ;;
  *)
    printf 'FALHA        perfil inválido: %s; use ci-h2 ou oracle\n' \
      "$DB_PROFILE"
    exit 2
    ;;
esac

if [[ "$CI_MODE" == true && "$DB_PROFILE" == "oracle" ]] &&
   rank_at_least CP-1D; then
  printf 'FALHA        --ci não permite o perfil oracle; use ci-h2\n'
  exit 2
fi

if rank_at_least CP-1D; then
  printf 'Doctor do laboratório — checkpoint %s, perfil %s\n\n' \
    "$CHECKPOINT" "$DB_PROFILE"
else
  printf 'Doctor do laboratório — checkpoint %s\n\n' "$CHECKPOINT"
fi

check_required_files
check_repository
check_sensitive_paths

if rank_at_least CP-1B; then
  if [[ "$CI_MODE" == true || "$NON_INTERACTIVE_MODE" == true ]]; then
    skip "runtime de containers (reprodução usa runtime externo direto)"
  else
    check_container_runtime
  fi
  check_network_defaults

  if ! rank_at_least CP-2A; then
    if rank_at_least CP-1D && [[ "$DB_PROFILE" == "ci-h2" ]]; then
      check_portable_java7
      skip "Oracle JDK 7u80 (perfil ci-h2)"
    elif [[ "$CI_MODE" == true ]]; then
      skip "Java 7u80 e checksum (bootstrap anterior ao CP-1D em CI)"
    else
      check_java "Java 7u80" JAVA7_HOME '1.7.0_80' \
        JAVA7_ARCHIVE JAVA7_ARCHIVE_SHA256 oracle-jdk
    fi

  else
    skip "Java 7 do baseline (encerrado antes do CP-2A)"
  fi

  if ! rank_at_least CP-2B; then
    if [[ "$CI_MODE" == true ]] && ! rank_at_least CP-1D; then
      skip "WildFly 9 e checksum (bootstrap anterior ao CP-1D em CI)"
    else
      check_wildfly "WildFly 9" WILDFLY9_HOME '9.0.2.Final' \
        WILDFLY9_ARCHIVE WILDFLY9_ARCHIVE_SHA256 wildfly
    fi
  else
    skip "WildFly 9 (encerrado antes do CP-2B)"
  fi
else
  skip "runtime de containers (entra no CP-1B)"
  skip "portas e bind de runtime (entram no CP-1B)"
  skip "Java 7 e WildFly 9 (entram no CP-1B)"
fi

if rank_at_least CP-1B && ! rank_at_least CP-2C; then
  if [[ "$CI_MODE" == true ]] && ! rank_at_least CP-1D; then
    skip "Maven 3.8.9 (bootstrap anterior ao CP-1D em CI)"
  elif rank_at_least CP-2A; then
    check_legacy_maven JAVA8_HOME '1.8.0' "Java 8"
  elif rank_at_least CP-1D && [[ "$DB_PROFILE" == "ci-h2" ]]; then
    check_legacy_maven JAVA7_PORTABLE_HOME '1.7.0_352' \
      "Zulu Java 7 portátil"
  else
    check_legacy_maven JAVA7_HOME '1.7.0_80' "Java 7u80"
  fi
else
  skip "Maven 3.8.9 (exigido de CP-1B a CP-2B)"
fi

if rank_at_least CP-1C && ! rank_at_least CP-2A; then
  if rank_at_least CP-1D && [[ "$DB_PROFILE" == "ci-h2" ]]; then
    skip "truststore externo do Oracle JDK (perfil ci-h2)"
  elif [[ "$CI_MODE" == true ]]; then
    skip "truststore atualizado (bootstrap anterior ao CP-1D em CI)"
  else
    check_java7_truststore
  fi
else
  skip "truststore atualizado do Oracle JDK (exigido de CP-1C a CP-1G)"
fi

if rank_at_least CP-1D && [[ "$DB_PROFILE" == "ci-h2" ]]; then
  check_h2
  skip "variáveis Oracle 19c e drivers JDBC externos (perfil ci-h2)"
elif rank_at_least CP-1D; then
  check_oracle_variables
  if rank_at_least CP-3C; then
    check_ojdbc17
  else
    check_ojdbc7
  fi
  skip "H2 portátil (perfil oracle)"
else
  skip "H2, variáveis Oracle 19c e drivers JDBC externos (entram no CP-1D)"
fi

if rank_at_least CP-2A && ! rank_at_least CP-3A; then
  check_phase2_java8
else
  skip "OpenJDK 8 e checksum (exigidos de CP-2A a CP-2D)"
fi

if rank_at_least CP-2B; then
  check_wildfly "WildFly 26" WILDFLY26_HOME '26.1.3.Final' WILDFLY26_ARCHIVE WILDFLY26_ARCHIVE_SHA256
else
  skip "WildFly 26 e checksum (entram no CP-2B)"
fi

if rank_at_least CP-2C; then
  check_modern_maven
else
  skip "Maven 3.9.16 (entra no CP-2C)"
fi

if rank_at_least CP-3A; then
  check_phase3_java17
else
  skip "OpenJDK 17 e checksum (entram no CP-3A)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-3E; then
  check_java "OpenJDK 21" JAVA21_HOME 'version "21' JAVA21_ARCHIVE JAVA21_ARCHIVE_SHA256
  check_wildfly "WildFly 41" WILDFLY41_HOME '41.0.0.Final' WILDFLY41_ARCHIVE WILDFLY41_ARCHIVE_SHA256
else
  skip "OpenJDK 21 e checksum (entram no CP-3E)"
  skip "WildFly 41 e checksum (entram no CP-3E)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-3J; then
  check_java "OpenJDK 25" JAVA25_HOME 'version "25' JAVA25_ARCHIVE JAVA25_ARCHIVE_SHA256
else
  skip "OpenJDK 25 e checksum (entram no CP-3J)"
fi

printf '\nResumo: %d OK, %d falha(s), %d aviso(s), %d não exigido(s).\n' \
  "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
