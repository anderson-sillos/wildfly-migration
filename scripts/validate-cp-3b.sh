#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_FILE="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
WAR_FILE=""
H2_RESULT_FILE=""
H2_CONTRACT_FILE=""
H2_LOGGING_RESULT_FILE=""
H2_UPLOAD_RESULT_FILE=""
H2_DISCOVERY_RESULT_FILE=""
ORACLE_RESULT_FILE=""
ORACLE_CONTRACT_FILE=""
ORACLE_LOGGING_RESULT_FILE=""
ORACLE_UPLOAD_RESULT_FILE=""
ORACLE_DISCOVERY_RESULT_FILE=""
CLOSURE_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3B/closure.properties"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3b.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3b.sh
  ./scripts/validate-cp-3b.sh --war ARQUIVO \
    [--h2-result ARQUIVO] [--h2-contract ARQUIVO] \
    [--h2-logging-result ARQUIVO] \
    [--h2-upload-result ARQUIVO] \
    [--h2-discovery-result ARQUIVO] \
    [--oracle-result ARQUIVO] [--oracle-contract ARQUIVO] \
    [--oracle-logging-result ARQUIVO] \
    [--oracle-upload-result ARQUIVO] \
    [--oracle-discovery-result ARQUIVO]

Sem argumentos, valida a estrutura versionada do CP-3B. Os resultados
dinâmicos são opcionais durante o desenvolvimento e obrigatórios nas
qualificações correspondentes.
USAGE
}

fail() {
  printf 'FALHA CP-3B: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3b.*)
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
    --h2-result)
      [[ $# -ge 2 ]] || fail "--h2-result exige um arquivo"
      H2_RESULT_FILE="$2"
      shift 2
      ;;
    --h2-contract)
      [[ $# -ge 2 ]] || fail "--h2-contract exige um arquivo"
      H2_CONTRACT_FILE="$2"
      shift 2
      ;;
    --h2-logging-result)
      [[ $# -ge 2 ]] || fail "--h2-logging-result exige um arquivo"
      H2_LOGGING_RESULT_FILE="$2"
      shift 2
      ;;
    --h2-upload-result)
      [[ $# -ge 2 ]] || fail "--h2-upload-result exige um arquivo"
      H2_UPLOAD_RESULT_FILE="$2"
      shift 2
      ;;
    --h2-discovery-result)
      [[ $# -ge 2 ]] || fail "--h2-discovery-result exige um arquivo"
      H2_DISCOVERY_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-result)
      [[ $# -ge 2 ]] || fail "--oracle-result exige um arquivo"
      ORACLE_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-contract)
      [[ $# -ge 2 ]] || fail "--oracle-contract exige um arquivo"
      ORACLE_CONTRACT_FILE="$2"
      shift 2
      ;;
    --oracle-logging-result)
      [[ $# -ge 2 ]] || fail "--oracle-logging-result exige um arquivo"
      ORACLE_LOGGING_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-upload-result)
      [[ $# -ge 2 ]] || fail "--oracle-upload-result exige um arquivo"
      ORACLE_UPLOAD_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-discovery-result)
      [[ $# -ge 2 ]] || fail "--oracle-discovery-result exige um arquivo"
      ORACLE_DISCOVERY_RESULT_FILE="$2"
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

required_paths=(
  "app/pom.xml"
  "docs/cp-3b-core-dependencies.md"
  "docs/evidence/CP-3B.md"
  "docs/mybatis-persistence.md"
  "docs/cp-3b-logging-bridge.md"
  "docs/cp-3b-fileupload.md"
  "docs/cp-3b-reflections-bridge.md"
  "migration/steps/CP-3B-mybatis-3.5.19.md"
  "migration/steps/CP-3B-log4j-over-slf4j.md"
  "migration/steps/CP-3B-commons-fileupload-1.6.0.md"
  "migration/steps/CP-3B-reflections-0.10.2.md"
  "migration/evidence/CP-3B/closure.properties"
  "app/src/main/java/br/com/asillos/migration/integration/validation/Validator.java"
  "app/src/main/webapp/WEB-INF/jboss-deployment-structure.xml"
  "runtime/phase2/java8-wildfly26/war-libraries.txt"
  "runtime/phase3/java17-wildfly26/war-libraries.txt"
  "scripts/build-cp-3b.sh"
  "scripts/smoke-cp-3b-datasource.sh"
  "scripts/validate-cp-3b.sh"
)

for path in "${required_paths[@]}"; do
  [[ -f "$REPOSITORY_ROOT/$path" ]] ||
    fail "arquivo obrigatório ausente: $path"
done

grep -Fq '<mybatis.version>3.5.19</mybatis.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa MyBatis 3.5.19"

current_allowlist="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt"
phase2_allowlist="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
[[ "$(grep -Ec '^mybatis-[^/]+\.jar$' "$current_allowlist")" == "1" ]] ||
  fail "allowlist Java 17 deve conter exatamente um JAR MyBatis"
grep -Fxq 'mybatis-3.5.19.jar' "$current_allowlist" ||
  fail "allowlist Java 17 não contém MyBatis 3.5.19"
if grep -Fq 'mybatis-3.4.5.jar' "$current_allowlist"; then
  fail "allowlist Java 17 ainda contém MyBatis 3.4.5"
fi
grep -Fxq 'mybatis-3.4.5.jar' "$phase2_allowlist" ||
  fail "allowlist histórica da fase 2 foi alterada"
if grep -Fq 'mybatis-3.5.19.jar' "$phase2_allowlist"; then
  fail "MyBatis novo foi atribuído retroativamente à fase 2"
fi

grep -Fq '<slf4j.version>1.7.36</slf4j.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa a ponte SLF4J 1.7.36"
grep -Fq '<artifactId>log4j-over-slf4j</artifactId>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não declara log4j-over-slf4j"
grep -Fq '<artifactId>slf4j-api</artifactId>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não declara a API SLF4J fornecida pelo WildFly"
if grep -Fq '<groupId>log4j</groupId>' "$REPOSITORY_ROOT/app/pom.xml" ||
   grep -Fq '<artifactId>log4j</artifactId>' \
     "$REPOSITORY_ROOT/app/pom.xml"; then
  fail "POM ainda declara Log4j 1"
fi
[[ ! -e "$REPOSITORY_ROOT/app/src/main/resources/log4j.properties" ]] ||
  fail "log4j.properties não pode permanecer no WAR do CP-3B"
grep -Fq '<module name="org.apache.log4j"/>' \
  "$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/jboss-deployment-structure.xml" ||
  fail "deployment não exclui o módulo Log4j 1 depreciado do WildFly"

[[ "$(grep -Ec '^log4j-over-slf4j-[^/]+\.jar$' \
  "$current_allowlist")" == "1" ]] ||
  fail "allowlist Java 17 deve conter exatamente uma ponte Log4j"
grep -Fxq 'log4j-over-slf4j-1.7.36.jar' "$current_allowlist" ||
  fail "allowlist Java 17 não contém a ponte 1.7.36"
if grep -Eq \
    '^(log4j-1|slf4j-api|slf4j-simple|slf4j-log4j12|logback-classic|log4j-core)[^/]*\.jar$' \
    "$current_allowlist"; then
  fail "allowlist Java 17 contém Log4j 1, API fornecida ou backend concorrente"
fi
grep -Fxq 'log4j-1.2.14.jar' "$phase2_allowlist" ||
  fail "allowlist histórica da fase 2 perdeu Log4j 1.2.14"
if grep -Fq 'log4j-over-slf4j' "$phase2_allowlist"; then
  fail "ponte de logging foi atribuída retroativamente à fase 2"
fi

for profile in ci-h2 oracle; do
  profile_file="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/$profile.cli"
  for marker in \
    'pattern-formatter=MIGRATION_PATTERN' \
    '%X{correlationId}' \
    'logger=br.com.asillos.migration'; do
    grep -Fq "$marker" "$profile_file" ||
      fail "perfil $profile não contém configuração de logging: $marker"
  done
done

for source in \
  app/src/main/java/br/com/asillos/migration/web/RequestContextFilter.java \
  app/src/main/java/br/com/asillos/migration/web/PedidoServlet.java \
  app/src/main/java/br/com/asillos/migration/web/UploadServlet.java \
  app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java \
  app/src/main/java/br/com/asillos/migration/integration/xml/LegacyPedidoXmlParser.java; do
  grep -Fq 'org.apache.log4j' "$REPOSITORY_ROOT/$source" ||
    fail "ponte deixou de ser necessária antes da atividade 3.34: $source"
done

grep -Fq '<commons.fileupload.version>1.6.0</commons.fileupload.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa Commons FileUpload 1.6.0"
grep -Fq '<commons.io.version>2.19.0</commons.io.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa Commons IO 2.19.0"
for library in \
  commons-fileupload-1.6.0.jar \
  commons-io-2.19.0.jar; do
  grep -Fxq "$library" "$current_allowlist" ||
    fail "allowlist Java 17 não contém $library"
done
if grep -Eq \
    '^(commons-fileupload-1\.2\.2|commons-io-1\.3\.2)\.jar$' \
    "$current_allowlist"; then
  fail "allowlist Java 17 ainda contém FileUpload/Commons IO legados"
fi
for library in \
  commons-fileupload-1.2.2.jar \
  commons-io-1.3.2.jar; do
  grep -Fxq "$library" "$phase2_allowlist" ||
    fail "allowlist histórica da fase 2 perdeu $library"
done
if grep -Eq \
    '^(commons-fileupload-1\.6\.0|commons-io-2\.19\.0)\.jar$' \
    "$phase2_allowlist"; then
  fail "FileUpload/Commons IO novos foram atribuídos à fase 2"
fi

if ! grep -Fq 'https://jakarta.ee/xml/ns/jakartaee' \
    "$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/web.xml"; then
  upload_source="$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/web/UploadServlet.java"
  for marker in \
    'javax.servlet.http.HttpServlet' \
    'ServletFileUpload.isMultipartContent(request)' \
    'setFileSizeMax(AnexoRepository.MAX_FILE_BYTES)' \
    'setSizeMax(MAX_REQUEST_BYTES)' \
    'item.delete()'; do
    grep -Fq "$marker" "$upload_source" ||
      fail "upload transitório não preserva: $marker"
  done
  if grep -Fq 'jakarta.servlet' "$upload_source"; then
    fail "atividade 3.8 não pode antecipar o namespace Jakarta"
  fi
fi

grep -Fq '<reflections.version>0.10.2</reflections.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa Reflections 0.10.2"
for library in \
  reflections-0.10.2.jar \
  javassist-3.28.0-GA.jar \
  jsr305-3.0.2.jar; do
  grep -Fxq "$library" "$current_allowlist" ||
    fail "allowlist Java 17 não contém $library"
done
if grep -Eq \
    '^(reflections-0\.9\.10|javassist-3\.19\.0-GA|annotations-2\.0\.1|guava-15\.0|slf4j-api-[^/]+)\.jar$' \
    "$current_allowlist"; then
  fail "allowlist Java 17 contém transitiva legada ou API SLF4J duplicada"
fi
for library in \
  reflections-0.9.10.jar \
  javassist-3.19.0-GA.jar \
  annotations-2.0.1.jar \
  guava-15.0.jar; do
  grep -Fxq "$library" "$phase2_allowlist" ||
    fail "allowlist histórica da fase 2 perdeu $library"
done

if ! grep -Fq 'https://jakarta.ee/xml/ns/jakartaee' \
    "$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/web.xml"; then
  discovery_source="$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/integration/validation/LegacyValidatorDiscovery.java"
  for marker in \
    'getTypesAnnotatedWith(Validator.class)' \
    'Scanners.TypesAnnotated' \
    'Scanners.SubTypes' \
    'setClassLoaders(new ClassLoader[] {classLoader})' \
    'PedidoImportValidator.class.isAssignableFrom(type)' \
    'legacy_validator_discovery classloader=' \
    'Collections.sort(names)'; do
    grep -Fq "$marker" "$discovery_source" ||
      fail "descoberta Reflections não preserva: $marker"
  done
  for validator_source in \
    NumeroFormatoValidator.java \
    ValorMonetarioValidator.java \
    StatusInicialValidator.java; do
    grep -Fq '@Validator' \
      "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/integration/validation/$validator_source" ||
      fail "validador não possui @Validator: $validator_source"
  done
fi

for marker in \
  'MyBatis 3.5.19' \
  'MyBatis 3.4.5' \
  'logImpl' \
  'atividade 3.34' \
  'aliases' \
  'type handlers' \
  'reflexão' \
  'rollback de uma falha intencional'; do
  grep -Fiq "$marker" "$REPOSITORY_ROOT/docs/mybatis-persistence.md" ||
    fail "documentação MyBatis não contém: $marker"
done

validate_mybatis_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado MyBatis ausente: $file"
  for marker in \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"mybatisVersion": "3.5.19"' \
    '"mappers": "passed"' \
    '"aliases": "passed"' \
    '"typeHandlers": "passed"' \
    '"reflection": "passed"' \
    '"mybatisCommit": "passed"' \
    '"mybatisRollback": "passed"'; do
    grep -Fq "$marker" "$file" ||
      fail "resultado MyBatis não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' "$file"; then
    fail "resultado MyBatis contém configuração sensível"
  fi
}

validate_contract_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado de contrato ausente: $file"
  grep -Fq "\"qualification\": \"$qualification\"" "$file" ||
    fail "contrato não contém qualificação $qualification"
  grep -Fq "\"profile\": \"$profile\"" "$file" ||
    fail "contrato não contém perfil $profile"
  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' "$file")" == "14" ]] ||
    fail "contrato não contém os 14 cenários aprovados"
}

validate_logging_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado de logging ausente: $file"
  for marker in \
    '"schema": "wildfly-migration-logging-compatibility/v1"' \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"bridge": "log4j-over-slf4j-1.7.36"' \
    '"backend": "wildfly-jboss-logmanager"' \
    '"log4j1ArtifactAbsent": "passed"' \
    '"bridgePresent": "passed"' \
    '"serverSlf4jApi": "passed"' \
    '"mdcCorrelation": "passed"' \
    '"loggerCategory": "passed"' \
    '"throwableStackTrace": "passed"' \
    '"deprecatedConfigurationWarningAbsent": "passed"' \
    '"backendConflictAbsent": "passed"'; do
    grep -Fq "$marker" "$file" ||
      fail "resultado de logging não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' "$file"; then
    fail "resultado de logging contém configuração sensível"
  fi
}

validate_upload_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado de upload ausente: $file"
  for marker in \
    '"schema": "wildfly-migration-upload-compatibility/v1"' \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"fileUploadVersion": "1.6.0"' \
    '"commonsIoVersion": "2.19.0"' \
    '"apiNamespace": "javax.servlet"' \
    '"validUpload": "passed"' \
    '"normalizedFilename": "passed"' \
    '"metadataRoundTrip": "passed"' \
    '"fileSizeLimit": "passed"' \
    '"requestSizeLimit": "passed"' \
    '"temporaryCleanup": "passed"'; do
    grep -Fq "$marker" "$file" ||
      fail "resultado de upload não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' "$file"; then
    fail "resultado de upload contém configuração sensível"
  fi
}

validate_discovery_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado de descoberta ausente: $file"
  for marker in \
    '"schema": "wildfly-migration-validator-discovery/v1"' \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"reflectionsVersion": "0.10.2"' \
    '"annotation": "br.com.asillos.migration.integration.validation.Validator"' \
    '"scanners": "TypesAnnotated+SubTypes"' \
    '"classLoader": "org.jboss.modules.ModuleClassLoader"' \
    '"validatorSet": "br.com.asillos.migration.integration.validation.NumeroFormatoValidator,br.com.asillos.migration.integration.validation.StatusInicialValidator,br.com.asillos.migration.integration.validation.ValorMonetarioValidator"' \
    '"validatorOrder": "numero-formato,valor-monetario,status-inicial"' \
    '"annotationDiscovery": "passed"' \
    '"eligibleTypes": "passed"' \
    '"classLoader": "passed"' \
    '"deterministicSet": "passed"' \
    '"deterministicOrder": "passed"' \
    '"domainRejection": "passed"'; do
    grep -Fq "$marker" "$file" ||
      fail "resultado de descoberta não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' "$file"; then
    fail "resultado de descoberta contém configuração sensível"
  fi
}

if grep -Fq -- \
    '- [x] 3.6 Atualizar MyBatis para 3.5.19' "$TASKS_FILE"; then
  for evidence in \
    "migration/evidence/CP-3B/mybatis-ci-h2.json" \
    "migration/evidence/CP-3B/mybatis-oracle.json"; do
    [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
      fail "evidência obrigatória da atividade 3.6 ausente: $evidence"
  done
  validate_mybatis_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-ci-h2.json" \
    portable-ci ci-h2
  validate_mybatis_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-oracle.json" \
    oracle-qualified oracle

  h2_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-ci-h2.json"
  oracle_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-oracle.json"
  h2_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' "$h2_evidence"
  )"
  oracle_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' "$oracle_evidence"
  )"
  h2_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' "$h2_evidence"
  )"
  oracle_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' "$oracle_evidence"
  )"
  [[ "$h2_source_commit" =~ ^[0-9a-f]{40}$ &&
     "$h2_source_commit" == "$oracle_source_commit" ]] ||
    fail "evidências H2 e Oracle não usam o mesmo commit-fonte"
  [[ "$h2_war_sha256" =~ ^[0-9a-f]{64}$ &&
     "$h2_war_sha256" == "$oracle_war_sha256" ]] ||
    fail "evidências H2 e Oracle não usam o mesmo WAR"
  git -C "$REPOSITORY_ROOT" cat-file -e \
    "${h2_source_commit}^{commit}" 2>/dev/null ||
    fail "commit-fonte das evidências MyBatis não existe"
fi

if grep -Fq -- \
    '- [x] 3.8 Atualizar Commons FileUpload' "$TASKS_FILE"; then
  for evidence in \
    "migration/evidence/CP-3B/upload-ci-h2.json" \
    "migration/evidence/CP-3B/upload-oracle.json"; do
    [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
      fail "evidência obrigatória da atividade 3.8 ausente: $evidence"
  done
  validate_upload_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/upload-ci-h2.json" \
    portable-ci ci-h2
  validate_upload_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/upload-oracle.json" \
    oracle-qualified oracle

  h2_upload_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/upload-ci-h2.json"
  oracle_upload_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/upload-oracle.json"
  h2_upload_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$h2_upload_evidence"
  )"
  oracle_upload_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$oracle_upload_evidence"
  )"
  h2_upload_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$h2_upload_evidence"
  )"
  oracle_upload_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$oracle_upload_evidence"
  )"
  [[ "$h2_upload_source_commit" =~ ^[0-9a-f]{40}$ &&
     "$h2_upload_source_commit" == "$oracle_upload_source_commit" ]] ||
    fail "evidências de upload H2 e Oracle não usam o mesmo commit-fonte"
  [[ "$h2_upload_war_sha256" =~ ^[0-9a-f]{64}$ &&
     "$h2_upload_war_sha256" == "$oracle_upload_war_sha256" ]] ||
    fail "evidências de upload H2 e Oracle não usam o mesmo WAR"
  git -C "$REPOSITORY_ROOT" cat-file -e \
    "${h2_upload_source_commit}^{commit}" 2>/dev/null ||
    fail "commit-fonte das evidências de upload não existe"
fi

if grep -Fq -- \
    '- [x] 3.7 Remover `log4j:log4j`' "$TASKS_FILE"; then
  for evidence in \
    "migration/evidence/CP-3B/logging-ci-h2.json" \
    "migration/evidence/CP-3B/logging-oracle.json"; do
    [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
      fail "evidência obrigatória da atividade 3.7 ausente: $evidence"
  done
  validate_logging_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/logging-ci-h2.json" \
    portable-ci ci-h2
  validate_logging_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/logging-oracle.json" \
    oracle-qualified oracle

  h2_logging_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/logging-ci-h2.json"
  oracle_logging_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/logging-oracle.json"
  h2_logging_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$h2_logging_evidence"
  )"
  oracle_logging_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$oracle_logging_evidence"
  )"
  h2_logging_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$h2_logging_evidence"
  )"
  oracle_logging_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$oracle_logging_evidence"
  )"
  [[ "$h2_logging_source_commit" =~ ^[0-9a-f]{40}$ &&
     "$h2_logging_source_commit" == "$oracle_logging_source_commit" ]] ||
    fail "evidências de logging H2 e Oracle não usam o mesmo commit-fonte"
  [[ "$h2_logging_war_sha256" =~ ^[0-9a-f]{64}$ &&
     "$h2_logging_war_sha256" == "$oracle_logging_war_sha256" ]] ||
    fail "evidências de logging H2 e Oracle não usam o mesmo WAR"
  git -C "$REPOSITORY_ROOT" cat-file -e \
    "${h2_logging_source_commit}^{commit}" 2>/dev/null ||
    fail "commit-fonte das evidências de logging não existe"
fi

if grep -Fq -- \
    '- [x] 3.9 Atualizar Reflections para 0.10.2' "$TASKS_FILE"; then
  for evidence in \
    "migration/evidence/CP-3B/discovery-ci-h2.json" \
    "migration/evidence/CP-3B/discovery-oracle.json"; do
    [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
      fail "evidência obrigatória da atividade 3.9 ausente: $evidence"
  done
  h2_discovery_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/discovery-ci-h2.json"
  oracle_discovery_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/discovery-oracle.json"
  validate_discovery_result \
    "$h2_discovery_evidence" portable-ci ci-h2
  validate_discovery_result \
    "$oracle_discovery_evidence" oracle-qualified oracle

  h2_discovery_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$h2_discovery_evidence"
  )"
  oracle_discovery_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
      "$oracle_discovery_evidence"
  )"
  h2_discovery_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$h2_discovery_evidence"
  )"
  oracle_discovery_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
      "$oracle_discovery_evidence"
  )"
  [[ "$h2_discovery_source_commit" =~ ^[0-9a-f]{40}$ &&
     "$h2_discovery_source_commit" == "$oracle_discovery_source_commit" ]] ||
    fail "evidências de descoberta H2 e Oracle não usam o mesmo commit-fonte"
  [[ "$h2_discovery_war_sha256" =~ ^[0-9a-f]{64}$ &&
     "$h2_discovery_war_sha256" == "$oracle_discovery_war_sha256" ]] ||
    fail "evidências de descoberta H2 e Oracle não usam o mesmo WAR"
  git -C "$REPOSITORY_ROOT" cat-file -e \
    "${h2_discovery_source_commit}^{commit}" 2>/dev/null ||
    fail "commit-fonte das evidências de descoberta não existe"
fi

if grep -Fq -- \
    '- [x] 3.10 Encerrar `CP-3B`' "$TASKS_FILE"; then
  [[ -f "$CLOSURE_EVIDENCE" ]] ||
    fail "evidência de fechamento CP-3B ausente"
  for marker in \
    'schema=wildfly-migration-cp3b-closure/v1' \
    'checkpoint=CP-3B' \
    'pull-request=20' \
    'tested.commit=84fb02f37e4eaf522d98de66697807b03dfa574a' \
    'documentation.commit=84fb02f37e4eaf522d98de66697807b03dfa574a' \
    'war.sha256=d3866778808f442b02691e1739ca7f0e8c1e6ec1c9dea7d99e72c9505362b5b5' \
    'maven.tree.sha256=47517b7396beadb34c08515f8631ec7ce59a6fdf173345d78f562c61e3d2d5a1' \
    'java.version=17.0.20+8' \
    'maven.version=3.9.16' \
    'wildfly.version=26.1.3.Final' \
    'portable-ci.contract.scenarios=14' \
    'portable-ci.discovery=passed' \
    'portable-ci.result=passed' \
    'portable.run.id=30650580350' \
    'portable.run.url=https://github.com/anderson-sillos/wildfly-migration/actions/runs/30650580350' \
    'portable.head.sha=84fb02f37e4eaf522d98de66697807b03dfa574a' \
    'oracle.database.version=19.3.0.0.0' \
    'oracle-qualified.contract.scenarios=14' \
    'oracle-qualified.discovery=passed' \
    'oracle-qualified.result=passed' \
    'transient.oracle.data.cleanup=passed' \
    'rollback.commit=6d94e5fc735575fa2ac644690a2a0635d921199f' \
    'rollback.result=verified-by-commit' \
    'squash.subject=checkpoint(CP-3B): modernize core dependencies' \
    'result=passed'; do
    grep -Fxq "$marker" "$CLOSURE_EVIDENCE" ||
      fail "evidência de fechamento CP-3B não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$CLOSURE_EVIDENCE"; then
    fail "evidência de fechamento CP-3B contém configuração sensível"
  fi
fi

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"
  [[ "$(grep -Ec '^WEB-INF/lib/mybatis-[^/]+\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt")" == "1" ]] ||
    fail "WAR deve conter exatamente um JAR MyBatis"
  grep -Fxq 'WEB-INF/lib/mybatis-3.5.19.jar' \
    "$TEMP_DIRECTORY/war-entries.txt" ||
    fail "WAR não contém MyBatis 3.5.19"
  if grep -Fq 'WEB-INF/lib/mybatis-3.4.5.jar' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR ainda contém MyBatis 3.4.5"
  fi
  grep -Fxq 'WEB-INF/lib/log4j-over-slf4j-1.7.36.jar' \
    "$TEMP_DIRECTORY/war-entries.txt" ||
    fail "WAR não contém a ponte Log4j sobre SLF4J"
  if grep -Eq \
      '^WEB-INF/lib/(log4j-1|slf4j-api|slf4j-simple|slf4j-log4j12|logback-classic|log4j-core)[^/]*\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR contém Log4j 1, API fornecida ou backend concorrente"
  fi
  grep -Fxq 'WEB-INF/jboss-deployment-structure.xml' \
    "$TEMP_DIRECTORY/war-entries.txt" ||
    fail "WAR não contém isolamento do módulo Log4j 1"
  if grep -Fq 'WEB-INF/classes/log4j.properties' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR ainda contém log4j.properties"
  fi
  for library in \
    commons-fileupload-1.6.0.jar \
    commons-io-2.19.0.jar; do
    grep -Fxq "WEB-INF/lib/$library" "$TEMP_DIRECTORY/war-entries.txt" ||
      fail "WAR não contém $library"
  done
  if grep -Eq \
      '^WEB-INF/lib/(commons-fileupload-1\.2\.2|commons-io-1\.3\.2)\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR ainda contém FileUpload/Commons IO legados"
  fi
  for library in \
    reflections-0.10.2.jar \
    javassist-3.28.0-GA.jar \
    jsr305-3.0.2.jar; do
    grep -Fxq "WEB-INF/lib/$library" "$TEMP_DIRECTORY/war-entries.txt" ||
      fail "WAR não contém $library"
  done
  if grep -Eq \
      '^WEB-INF/lib/(reflections-0\.9\.10|javassist-3\.19\.0-GA|annotations-2\.0\.1|guava-15\.0|slf4j-api-[^/]+)\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR contém transitiva legada ou API SLF4J duplicada"
  fi
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
else
  war_sha256=""
fi

if [[ -n "$H2_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-result exige --war"
  validate_mybatis_result "$H2_RESULT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$H2_RESULT_FILE" ||
    fail "resultado MyBatis H2 não corresponde ao WAR"
fi
if [[ -n "$H2_CONTRACT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-contract exige --war"
  validate_contract_result "$H2_CONTRACT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$H2_CONTRACT_FILE" ||
    fail "contrato H2 não corresponde ao WAR"
fi
if [[ -n "$H2_LOGGING_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-logging-result exige --war"
  validate_logging_result \
    "$H2_LOGGING_RESULT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$H2_LOGGING_RESULT_FILE" ||
    fail "resultado de logging H2 não corresponde ao WAR"
fi
if [[ -n "$H2_UPLOAD_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-upload-result exige --war"
  validate_upload_result "$H2_UPLOAD_RESULT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$H2_UPLOAD_RESULT_FILE" ||
    fail "resultado de upload H2 não corresponde ao WAR"
fi
if [[ -n "$H2_DISCOVERY_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-discovery-result exige --war"
  validate_discovery_result \
    "$H2_DISCOVERY_RESULT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$H2_DISCOVERY_RESULT_FILE" ||
    fail "resultado de descoberta H2 não corresponde ao WAR"
fi
if [[ -n "$ORACLE_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-result exige --war"
  validate_mybatis_result \
    "$ORACLE_RESULT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$ORACLE_RESULT_FILE" ||
    fail "resultado MyBatis Oracle não corresponde ao WAR"
  grep -Fq '"databaseVersion": "19.3.0.0.0"' "$ORACLE_RESULT_FILE" ||
    fail "resultado MyBatis Oracle não identifica o RU 19.3"
fi
if [[ -n "$ORACLE_CONTRACT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-contract exige --war"
  validate_contract_result \
    "$ORACLE_CONTRACT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$ORACLE_CONTRACT_FILE" ||
    fail "contrato Oracle não corresponde ao WAR"
fi
if [[ -n "$ORACLE_LOGGING_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-logging-result exige --war"
  validate_logging_result \
    "$ORACLE_LOGGING_RESULT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$ORACLE_LOGGING_RESULT_FILE" ||
    fail "resultado de logging Oracle não corresponde ao WAR"
fi
if [[ -n "$ORACLE_UPLOAD_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-upload-result exige --war"
  validate_upload_result \
    "$ORACLE_UPLOAD_RESULT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$ORACLE_UPLOAD_RESULT_FILE" ||
    fail "resultado de upload Oracle não corresponde ao WAR"
fi
if [[ -n "$ORACLE_DISCOVERY_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-discovery-result exige --war"
  validate_discovery_result \
    "$ORACLE_DISCOVERY_RESULT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" \
    "$ORACLE_DISCOVERY_RESULT_FILE" ||
    fail "resultado de descoberta Oracle não corresponde ao WAR"
fi

printf 'OK: MyBatis, logging, upload e descoberta isolados no CP-3B\n'
