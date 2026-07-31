#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POM="$REPOSITORY_ROOT/app/pom.xml"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
RUNTIME_CACHE_LOCK="$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
RUNTIME_CACHE_SOURCES="$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv"
WORKFLOW="$REPOSITORY_ROOT/.github/workflows/validate.yml"
CACHE_CLEANUP_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/pr-cache-cleanup.yml"
EVIDENCE_DIRECTORY="$REPOSITORY_ROOT/migration/evidence/CP-2C"
WAR_FILE=""
CONTRACT_RESULT_FILE=""
ORACLE_PERSISTENCE_RESULT_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2c.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso: ./scripts/validate-cp-2c.sh [--war ARQUIVO] \
  [--contract-result ARQUIVO] [--oracle-persistence-result ARQUIVO]

Sem argumentos, valida estaticamente o alinhamento ao Jakarta EE 8.
Com --war, comprova também a ausência de APIs do contêiner em WEB-INF/lib.
Com --contract-result, valida o relatório H2 ou Oracle produzido para o WAR.
Com --oracle-persistence-result, valida a sonda específica Oracle 19c.
USAGE
}

fail() {
  printf 'FALHA CP-2C: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2c.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --contract-result)
      [[ $# -ge 2 ]] || fail "--contract-result exige um arquivo"
      CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-persistence-result)
      [[ $# -ge 2 ]] ||
        fail "--oracle-persistence-result exige um arquivo"
      ORACLE_PERSISTENCE_RESULT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

if [[ -n "$CONTRACT_RESULT_FILE$ORACLE_PERSISTENCE_RESULT_FILE" &&
      -z "$WAR_FILE" ]]; then
  fail "resultados dinâmicos exigem também --war"
fi

for path in \
  "$POM" \
  "$EXPECTED_LIBRARIES" \
  "$RUNTIME_CACHE_LOCK" \
  "$RUNTIME_CACHE_SOURCES" \
  "$WORKFLOW" \
  "$CACHE_CLEANUP_WORKFLOW" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv" \
  "$REPOSITORY_ROOT/docs/cp-2c-ee8-maven-datasource.md" \
  "$REPOSITORY_ROOT/docs/evidence/CP-2C.md" \
  "$EVIDENCE_DIRECTORY/after.properties" \
  "$EVIDENCE_DIRECTORY/contract-ci-h2.json" \
  "$EVIDENCE_DIRECTORY/contract-oracle.json" \
  "$EVIDENCE_DIRECTORY/oracle-persistence.json" \
  "$REPOSITORY_ROOT/scripts/build-cp-2c.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-2c-oracle.sh" \
  "$REPOSITORY_ROOT/scripts/ValidateCp2cOraclePersistence.java" \
  "$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  "$REPOSITORY_ROOT/scripts/doctor.sh" \
  "$REPOSITORY_ROOT/scripts/ValidateApplicationPom.java" \
  "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for oracle_qualification_marker in \
  'doctor.sh" \' \
  'CP-2C --profile oracle' \
  'oracle-lab-schema.sh" \' \
  'verify --java 8' \
  'build-cp-2c.sh" \' \
  'smoke-wildfly26-datasource.sh" \' \
  'validate-cp-2c-oracle-persistence.sh" \' \
  'validate-cp-2c.sh" \' \
  '--oracle-persistence-result' \
  'cleanup-smokes --java 8'; do
  grep -Fq -- "$oracle_qualification_marker" \
    "$REPOSITORY_ROOT/scripts/qualify-cp-2c-oracle.sh" ||
    fail "qualificação Oracle não contém: $oracle_qualification_marker"
done

for cleanup_marker in \
  'types:' \
  '- closed' \
  'github.event.pull_request.head.repo.full_name ==' \
  'github.repository' \
  'actions: write' \
  'GH_TOKEN: ${{ github.token }}' \
  'PR_CACHE_REF: refs/pull/${{ github.event.pull_request.number }}/merge' \
  'gh cache delete --all' \
  '--ref "$PR_CACHE_REF"' \
  '--succeed-on-no-caches'; do
  grep -Fq -- "$cleanup_marker" "$CACHE_CLEANUP_WORKFLOW" ||
    fail "limpeza de caches temporários não contém: $cleanup_marker"
done
if grep -Fq -- '--confirm' "$CACHE_CLEANUP_WORKFLOW"; then
  fail "limpeza de cache usa a opção --confirm incompatível com o GitHub CLI"
fi
if grep -Fq 'uses: actions/checkout' "$CACHE_CLEANUP_WORKFLOW"; then
  fail "limpeza de cache não deve executar código do pull request fechado"
fi

for cache_marker in \
  'uses: actions/cache/restore@v5' \
  'uses: actions/cache/save@v5' \
  'path: ${{ runner.temp }}/wildfly-migration-cache/runtime-archives' \
  "key: runtime-archives-v4-\${{ runner.os }}-\${{ runner.arch }}-\${{ hashFiles('runtime/portable-runtime-cache.sha256') }}" \
  'runtime-archives-v4-${{ runner.os }}-${{ runner.arch }}-' \
  'path: ~/.m2/repository' \
  'key: maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.9.16-${{ hashFiles(' \
  'maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.9.16-' \
  'key: ${{ steps.runtime-archive-cache.outputs.cache-primary-key }}' \
  'key: ${{ steps.maven-dependency-cache.outputs.cache-primary-key }}' \
  'MIGRATION_CHECKPOINT=CP-3A' \
  './scripts/doctor.sh CP-3A --profile ci-h2 --ci' \
  './scripts/build-cp-3a.sh --profile ci-h2' \
  './scripts/validate-cp-2c-oracle-persistence.sh' \
  './scripts/validate-cp-2d-oracle-state.sh' \
  '--compile-only' \
  './scripts/validate-cp-3a.sh \' \
  '--promoted-war app/target/wildfly-migration.war' \
  'MIGRATION_SOURCE_COMMIT: >-' \
  '${{ github.event.pull_request.head.sha || github.sha }}' \
  'MAVEN_HOME=$tools/apache-maven-3.9.16' \
  'MAVEN_ARCHIVE_SHA256=80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb' \
  './scripts/prepare-portable-runtime-cache.sh \' \
  '--sources "$runtime_sources"' \
  'app/target/contract-results/cp-3a-ci-h2.json' \
  'cp-3a-portable-evidence'; do
  grep -Fq -- "$cache_marker" "$WORKFLOW" ||
    fail "workflow não contém o cache reutilizável: $cache_marker"
done
grep -Fq \
  $'apache-maven-3.9.16-bin.tar.gz\thttps://downloads.apache.org/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz' \
  "$RUNTIME_CACHE_SOURCES" ||
  fail "índice de origens do cache não contém a distribuição Maven"

for cache_lock_row in \
  'da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e  OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz' \
  '80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb  apache-maven-3.9.16-bin.tar.gz' \
  'aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59  wildfly-26.1.3.Final.tar.gz' \
  '3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6  h2-1.4.200.jar' \
  '29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0  h2-2.4.240.jar'; do
  grep -Fxq "$cache_lock_row" "$RUNTIME_CACHE_LOCK" ||
    fail "identidade do cache de runtime não contém: $cache_lock_row"
done

if [[ "$(grep -Fc 'uses: actions/cache/restore@v5' "$WORKFLOW")" -ne 2 ]] ||
   [[ "$(grep -Fc 'uses: actions/cache/save@v5' "$WORKFLOW")" -ne 2 ]]; then
  fail "workflow deve restaurar e salvar exatamente os caches de runtime e Maven"
fi

for cache_hit_guard in \
  "steps.runtime-archive-cache.outputs.cache-hit != 'true'" \
  "steps.maven-dependency-cache.outputs.cache-hit != 'true'"; do
  grep -Fq "$cache_hit_guard" "$WORKFLOW" ||
    fail "cache exato da main não pode ser duplicado no PR: $cache_hit_guard"
done

cache_save_section="$(
  sed -n '/- name: Save reusable runtime archive cache/,$p' "$WORKFLOW"
)"
for save_guard in \
  "github.event_name == 'push'" \
  "github.ref == 'refs/heads/main'" \
  "github.event_name == 'pull_request'" \
  "github.event.pull_request.head.repo.full_name ==" \
  "github.repository"; do
  if [[ "$(grep -Fc "$save_guard" <<< "$cache_save_section")" -ne 2 ]]; then
    fail "os dois caches não compartilham a proteção de gravação: $save_guard"
  fi
done

if grep -Fq 'uses: actions/cache@v5' "$WORKFLOW"; then
  fail "política de gravação exige actions separadas de restore e save"
fi

if grep -Eq \
    'key: cp-[0-9]|wildfly-migration-cache/cp-[0-9]' \
    "$WORKFLOW"; then
  fail "chave ou caminho de cache não deve depender de checkpoint"
fi

if grep -Ei \
    '^[[:space:]]+(key|path):.*(github\.token|GITHUB_TOKEN|GH_TOKEN|secrets\.)' \
    "$WORKFLOW"; then
  fail "token ou secret não pode participar de chave ou caminho de cache"
fi

for token_workflow in \
  "$REPOSITORY_ROOT/.github/workflows/validate.yml" \
  "$WORKFLOW"; do
  grep -Fq 'persist-credentials: false' "$token_workflow" ||
    fail "checkout deve tratar o token como credencial efêmera"
done

for marker in \
  '<modelVersion>4.0.0</modelVersion>' \
  '<id>enforce-java17-toolchain</id>' \
  '<version>[3.9.16]</version>'; do
  grep -Fq "$marker" "$POM" ||
    fail "POM não contém o contrato Maven do CP-2C: $marker"
done

grep -Fq -- '--java 8 --maven 3.9.16' \
  "$REPOSITORY_ROOT/scripts/build-cp-2c.sh" ||
  fail "wrapper CP-2C não fixa Java 8 e Maven 3.9.16"

grep -Fq 'if rank_at_least CP-2C; then' \
  "$REPOSITORY_ROOT/scripts/doctor.sh" ||
  fail "doctor não exige Maven 3.9.16 no CP-2C"
if grep -Fq \
    'if [[ "$CI_MODE" != true ]] && rank_at_least CP-2C; then' \
    "$REPOSITORY_ROOT/scripts/doctor.sh"; then
  fail "doctor não pode ignorar Maven 3.9.16 no CI do CP-2C"
fi
if grep -Fq \
    'if [[ "$CI_MODE" != true ]] && rank_at_least CP-2B; then' \
    "$REPOSITORY_ROOT/scripts/doctor.sh"; then
  fail "doctor não pode ignorar WildFly 26 no CI do CP-2C"
fi

expected_maven_row=$'apache-maven\t3.9.16\tapache-maven-3.9.16-bin.tar.gz\thttps://downloads.apache.org/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz\tApache-2.0\t80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb\tsha512:831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6\tmaintained-current-stable\tCP-2C-and-later'
grep -Fxq "$expected_maven_row" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv" ||
  fail "manifesto da fase 2 não fixa a distribuição Maven 3.9.16 aprovada"

for marker in \
  '<jakarta.ee.web.api.version>8.0.0</jakarta.ee.web.api.version>' \
  '<groupId>jakarta.platform</groupId>' \
  '<artifactId>jakarta.jakartaee-web-api</artifactId>' \
  '<version>${jakarta.ee.web.api.version}</version>' \
  '<scope>provided</scope>'; do
  grep -Fq "$marker" "$POM" ||
    fail "POM não contém o contrato EE 8: $marker"
done

for forbidden_coordinate in \
  '<artifactId>servlet-api</artifactId>' \
  '<artifactId>jsp-api</artifactId>' \
  '<artifactId>jstl-api</artifactId>' \
  '<artifactId>javaee-web-api</artifactId>'; do
  if grep -Fq "$forbidden_coordinate" "$POM"; then
    fail "POM ainda contém API histórica separada: $forbidden_coordinate"
  fi
done

if grep -R -E \
    '^[[:space:]]*import[[:space:]]+jakarta\.(servlet|el)\.' \
    "$REPOSITORY_ROOT/app/src/main/java"; then
  fail "CP-2C não deve antecipar a migração de namespace do gate Jakarta"
fi

grep -Fq -- \
  '- [x] 2.11 Alinhar as APIs do build a Jakarta EE 8' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.11 não está concluída no OpenSpec"

grep -Fq -- \
  '- [x] 2.12 Atualizar a ferramenta de build de Maven 3.8.9 para Maven 3.9.16' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.12 não está concluída no OpenSpec"

grep -Fq -- \
  '- [x] 2.13 Validar a paridade portátil em H2 e qualificar no Oracle' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.13 não está concluída no OpenSpec"

grep -Fq -- \
  '- [x] 2.14 Atualizar `doctor`, CI H2, qualificação Oracle e auditoria do WAR' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.14 não está concluída no OpenSpec"

grep -Fq -- \
  '- [x] 2.15 Encerrar `CP-2C`' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.15 não está concluída no OpenSpec"

evidence_source_commit="$(
  awk -F= '$1 == "implementation.commit" { print $2 }' \
    "$EVIDENCE_DIRECTORY/after.properties"
)"
evidence_portable_commit="$(
  awk -F= '$1 == "portable-ci.tested.commit" { print $2 }' \
    "$EVIDENCE_DIRECTORY/after.properties"
)"
evidence_war_sha256="$(
  awk -F= '$1 == "war.sha256" { print $2 }' \
    "$EVIDENCE_DIRECTORY/after.properties"
)"
[[ "$evidence_source_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "evidência CP-2C não identifica o commit de origem"
[[ "$evidence_portable_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "evidência CP-2C não identifica o merge testado no CI"
[[ "$evidence_war_sha256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "evidência CP-2C não identifica o WAR"

for marker in \
  'schema=wildfly-migration-evidence/v1' \
  'checkpoint=CP-2C' \
  'source.checkpoint=CP-2B' \
  'source.checkpoint.commit=3c0b80373370494ccccd15ec07be4dae8d51a155' \
  'war.bytecode.major=52' \
  'war.web-inf-lib.count=20' \
  'war.container-api-jars=0' \
  'target.java=Eclipse-Temurin-1.8.0_492-b09' \
  'target.wildfly=26.1.3.Final' \
  'target.maven=3.9.16' \
  'target.ee=Jakarta-EE-Web-Profile-8.0' \
  'target.namespace=javax' \
  'target.api.scope=provided' \
  'datasource.jndi=java:/jdbc/MigrationDS' \
  'datasource.pool.test=passed' \
  'portable-ci.result=passed' \
  'portable-ci.contract.scenarios=14' \
  'oracle-qualified.result=passed' \
  'oracle-qualified.contract.scenarios=14' \
  'oracle.database.version=19.3.0.0.0' \
  'oracle.jdbc.driver=ojdbc7-12.1.0.2.0' \
  'oracle.mybatis.commit=passed' \
  'oracle.mybatis.rollback=passed' \
  'oracle.timestamp6.round-trip=passed' \
  'oracle.blob.round-trip=passed' \
  'oracle.transient-data.cleanup=passed' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE_DIRECTORY/after.properties" ||
    fail "resumo CP-2C não contém: $marker"
done

for contract_profile in ci-h2 oracle; do
  contract_evidence="$EVIDENCE_DIRECTORY/contract-$contract_profile.json"
  if [[ "$contract_profile" == "ci-h2" ]]; then
    expected_qualification='"qualification": "portable-ci"'
    expected_tested_commit="$evidence_portable_commit"
  else
    expected_qualification='"qualification": "oracle-qualified"'
    expected_tested_commit="$evidence_source_commit"
  fi
  for marker in \
    '"schema": "wildfly-migration-contract-result/v1"' \
    "$expected_qualification" \
    "\"profile\": \"$contract_profile\"" \
    "\"commit\": \"$expected_tested_commit\"" \
    "\"sourceCommit\": \"$evidence_source_commit\"" \
    "\"warSha256\": \"$evidence_war_sha256\"" \
    '"runtime": "java8-wildfly26.1.3"'; do
    grep -Fq "$marker" "$contract_evidence" ||
      fail "contrato versionado $contract_profile não contém: $marker"
  done
  [[ "$(grep -Ec \
      '^[[:space:]]+\"[A-Za-z][A-Za-z0-9]*\": \"passed\",?$' \
      "$contract_evidence")" == "14" ]] ||
    fail "contrato versionado $contract_profile não contém 14 cenários"
done

for marker in \
  '"schema": "wildfly-migration-oracle-persistence/v1"' \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  "\"commit\": \"$evidence_source_commit\"" \
  "\"sourceCommit\": \"$evidence_source_commit\"" \
  "\"warSha256\": \"$evidence_war_sha256\"" \
  '"runtime": "java8-wildfly26.1.3-ee8"' \
  '"databaseVersion": "19.3.0.0.0"' \
  '"jdbcDriver": "ojdbc7-12.1.0.2.0"' \
  '"mybatisCommit": "passed"' \
  '"mybatisRollback": "passed"' \
  '"timestampRoundTrip": "passed"' \
  '"blobRoundTrip": "passed"' \
  '"transientDataCleanup": "passed"'; do
  grep -Fq "$marker" "$EVIDENCE_DIRECTORY/oracle-persistence.json" ||
    fail "persistência Oracle versionada não contém: $marker"
done

for documentation_marker in \
  '## Conclusão comprovada' \
  '### Limites da conclusão' \
  '## Rollback' \
  '30494074305' \
  '30494074318' \
  'sourceCommit' \
  'TIMESTAMP(6)' \
  'BLOB'; do
  grep -Fq "$documentation_marker" \
    "$REPOSITORY_ROOT/docs/evidence/CP-2C.md" ||
    fail "documentação da evidência não contém: $documentation_marker"
done

if grep -R -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$EVIDENCE_DIRECTORY"; then
  fail "evidência versionada CP-2C contém configuração sensível"
fi

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"

  awk '
    /^WEB-INF\/lib\/[^/]+\.jar$/ {
      sub(/^WEB-INF\/lib\//, "")
      print
    }
  ' "$TEMP_DIRECTORY/war-entries.txt" |
    LC_ALL=C sort >"$TEMP_DIRECTORY/actual-libraries.txt"

  if grep -Eq \
      '^WEB-INF/lib/(servlet-api|javax\.servlet-api|jakarta\.servlet-api|jsp-api|javax\.servlet\.jsp-api|jakarta\.servlet\.jsp-api|jstl-api|javax\.servlet\.jsp\.jstl-api|jakarta\.servlet\.jsp\.jstl-api|javax\.el-api|jakarta\.el-api|javaee-api|javaee-web-api|jakarta\.jakartaee-api|jakarta\.jakartaee-web-api)-[^/]+\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR contém uma API fornecida pelo WildFly"
  fi

  LC_ALL=C sort "$EXPECTED_LIBRARIES" \
    >"$TEMP_DIRECTORY/expected-libraries.txt"
  diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt" ||
    fail "WEB-INF/lib diverge da allowlist da fase 2"
fi

if [[ -n "$CONTRACT_RESULT_FILE" ]]; then
  [[ -f "$CONTRACT_RESULT_FILE" ]] ||
    fail "resultado de contrato informado não existe"
  current_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
  source_commit="${MIGRATION_SOURCE_COMMIT:-$current_commit}"
  current_war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  if grep -Fq '"profile": "ci-h2"' "$CONTRACT_RESULT_FILE"; then
    expected_qualification='"qualification": "portable-ci"'
  elif grep -Fq '"profile": "oracle"' "$CONTRACT_RESULT_FILE"; then
    expected_qualification='"qualification": "oracle-qualified"'
  else
    fail "resultado de contrato não identifica perfil conhecido"
  fi
  for marker in \
    '"schema": "wildfly-migration-contract-result/v1"' \
    "$expected_qualification" \
    "\"commit\": \"$current_commit\"" \
    "\"sourceCommit\": \"$source_commit\"" \
    "\"warSha256\": \"$current_war_sha256\"" \
    '"runtime": "java8-wildfly26.1.3"'; do
    grep -Fq "$marker" "$CONTRACT_RESULT_FILE" ||
      fail "resultado de contrato atual não contém: $marker"
  done
  [[ "$(grep -Ec \
      '^[[:space:]]+\"[A-Za-z][A-Za-z0-9]*\": \"passed\",?$' \
      "$CONTRACT_RESULT_FILE")" == "14" ]] ||
    fail "resultado de contrato atual não contém os 14 cenários aprovados"
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$CONTRACT_RESULT_FILE"; then
    fail "resultado de contrato atual contém configuração sensível"
  fi
fi

if [[ -n "$ORACLE_PERSISTENCE_RESULT_FILE" ]]; then
  [[ -f "$ORACLE_PERSISTENCE_RESULT_FILE" ]] ||
    fail "resultado de persistência Oracle informado não existe"
  current_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
  current_war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  for marker in \
    '"schema": "wildfly-migration-oracle-persistence/v1"' \
    '"qualification": "oracle-qualified"' \
    '"profile": "oracle"' \
    "\"commit\": \"$current_commit\"" \
    "\"sourceCommit\": \"$current_commit\"" \
    "\"warSha256\": \"$current_war_sha256\"" \
    '"runtime": "java8-wildfly26.1.3-ee8"' \
    '"databaseVersion": "19.3.0.0.0"' \
    '"jdbcDriver": "ojdbc7-12.1.0.2.0"' \
    '"mybatisCommit": "passed"' \
    '"mybatisRollback": "passed"' \
    '"timestampRoundTrip": "passed"' \
    '"blobRoundTrip": "passed"' \
    '"transientDataCleanup": "passed"'; do
    grep -Fq "$marker" "$ORACLE_PERSISTENCE_RESULT_FILE" ||
      fail "resultado Oracle atual não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$ORACLE_PERSISTENCE_RESULT_FILE"; then
    fail "resultado de persistência Oracle contém configuração sensível"
  fi
fi

printf 'OK: build alinhado ao Jakarta EE Web Profile 8 e Maven 3.9.16'
if [[ -n "$WAR_FILE" ]]; then
  printf ', sem APIs do contêiner em WEB-INF/lib'
fi
if [[ -n "$CONTRACT_RESULT_FILE" ]]; then
  printf ', contratos atuais aprovados'
fi
if [[ -n "$ORACLE_PERSISTENCE_RESULT_FILE" ]]; then
  printf ', persistência Oracle específica aprovada'
fi
printf '\n'
