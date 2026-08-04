#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
EVIDENCE="$ROOT/migration/evidence/CP-3H/packaging-audit.json"
WRITE_EVIDENCE=false
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3h-audit.XXXXXXXX)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/audit-cp-3h-final-packaging.sh [--war ARQUIVO]
    [--evidence ARQUIVO] [--write-evidence]

Audita dependências proibidas, APIs fornecidas pelo contêiner, conteúdo do
WAR e o JAR/descritor do ServletContainerInitializer do CP-3H/3.39.
USAGE
}

fail() {
  printf 'FALHA CP-3H/3.39: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3h-audit.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2 ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --evidence) [[ $# -ge 2 ]] || fail '--evidence exige um arquivo'; EVIDENCE="$2"; shift 2 ;;
    --write-evidence) WRITE_EVIDENCE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/app/pom.xml" \
  "$ROOT/app/src/main/resources/mybatis-config.xml" \
  "$ROOT/migration/steps/CP-3H-final-packaging-audit.md"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for forbidden in \
  '<artifactId>log4j</artifactId>' \
  '<artifactId>log4j-over-slf4j</artifactId>' \
  '<artifactId>log4j-core</artifactId>' \
  '<artifactId>tiles-' \
  '<artifactId>commons-fileupload</artifactId>' \
  '<artifactId>reflections</artifactId>' \
  '<artifactId>classgraph</artifactId>' \
  '<artifactId>scannotation</artifactId>' \
  '<artifactId>xml-apis</artifactId>' \
  '<artifactId>geronimo-stax-api_1.0_spec</artifactId>' \
  '<artifactId>stax-api</artifactId>' \
  '<artifactId>ojdbc7</artifactId>'; do
  if grep -Fqi "$forbidden" "$ROOT/app/pom.xml"; then
    fail "dependência proibida reapareceu no POM: $forbidden"
  fi
done

if ! awk '
  /<artifactId>jakarta\.jakartaee-web-api<\/artifactId>/ { dependency=1 }
  dependency && /<scope>provided<\/scope>/ { provided=1 }
  dependency && /<\/dependency>/ { if (provided) found=1; dependency=0; provided=0 }
  END { exit(found ? 0 : 1) }
' "$ROOT/app/pom.xml"; then
  fail 'jakarta.jakartaee-web-api não está explicitamente em provided'
fi

if grep -REni \
    'org\.apache\.log4j|log4j-over-slf4j|org\.apache\.tiles|commons\.fileupload|ServletFileUpload|DiskFileItemFactory|org\.reflections|classgraph|scannotation|xml-apis|geronimo-stax|stax-api|ojdbc7' \
    "$ROOT/app/src/main/java" "$ROOT/app/src/main/resources" "$ROOT/app/src/main/webapp"; then
  fail 'referência de biblioteca removida encontrada no código ativo'
fi
grep -Fq '<setting name="logImpl" value="SLF4J"/>' \
  "$ROOT/app/src/main/resources/mybatis-config.xml" ||
  fail 'MyBatis não fixa logImpl=SLF4J'

[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
WAR_ENTRIES="$TEMP_DIRECTORY/war-entries.txt"
SCI_JAR="$TEMP_DIRECTORY/wildfly-migration-validator-sci.jar"
SCI_ENTRIES="$TEMP_DIRECTORY/sci-entries.txt"
jar tf "$WAR_FILE" >"$WAR_ENTRIES"

for api_pattern in \
  '^WEB-INF/lib/(jakarta|javax|servlet|jsp|jstl|el|websocket|annotation|validation)-.*\.jar$' \
  '^WEB-INF/lib/.*(servlet|jsp|jstl|el|jakartaee|javax).*api.*\.jar$'; do
  if grep -Eiq "$api_pattern" "$WAR_ENTRIES"; then
    fail "API fornecida pelo contêiner empacotada no WAR: $api_pattern"
  fi
done
if grep -Eiq '^WEB-INF/lib/(tiles|commons-fileupload|reflections|classgraph|scannotation|log4j-(1|core|over-slf4j)|xml-apis|geronimo-stax|stax-api|ojdbc|h2-)[^/]*\.jar$' "$WAR_ENTRIES"; then
  fail 'biblioteca proibida ou infraestrutura de teste empacotada no WAR'
fi
if grep -Eiq '^WEB-INF/lib/log4j-(1|core|over-slf4j)[^/]*\.jar$' "$WAR_ENTRIES"; then
  fail 'Log4j 1 ou backend/ponte concorrente empacotado no WAR'
fi

grep -Fxq 'WEB-INF/lib/wildfly-migration-validator-sci.jar' "$WAR_ENTRIES" ||
  fail 'JAR interno do SCI não está em WEB-INF/lib'
if grep -Eiq '^WEB-INF/classes/br/com/asillos/migration/integration/validation/(Validator|PedidoImportValidator|ValidatorDiscovery(\$[^/]*)?|ValidatorServletContainerInitializer(\$[^/]*)?)\.class$' "$WAR_ENTRIES"; then
  fail 'infraestrutura do SCI foi duplicada em WEB-INF/classes'
fi
if grep -Fq 'WEB-INF/classes/META-INF/services/jakarta.servlet.ServletContainerInitializer' "$WAR_ENTRIES"; then
  fail 'descritor SCI foi duplicado em WEB-INF/classes'
fi
for validator in NumeroFormatoValidator StatusInicialValidator ValorMonetarioValidator; do
  grep -Fxq "WEB-INF/classes/br/com/asillos/migration/integration/validation/${validator}.class" "$WAR_ENTRIES" ||
    fail "validator concreto ausente em WEB-INF/classes: $validator"
done
unzip -p "$WAR_FILE" WEB-INF/lib/wildfly-migration-validator-sci.jar >"$SCI_JAR" ||
  fail 'não foi possível extrair o JAR interno do SCI'
jar tf "$SCI_JAR" >"$SCI_ENTRIES"
for entry in \
  br/com/asillos/migration/integration/validation/Validator.class \
  br/com/asillos/migration/integration/validation/PedidoImportValidator.class \
  br/com/asillos/migration/integration/validation/ValidatorDiscovery.class \
  br/com/asillos/migration/integration/validation/ValidatorDiscovery\$1.class \
  br/com/asillos/migration/integration/validation/ValidatorServletContainerInitializer.class \
  META-INF/services/jakarta.servlet.ServletContainerInitializer; do
  grep -Fxq "$entry" "$SCI_ENTRIES" || fail "JAR SCI não contém: $entry"
done
service_value="$(unzip -p "$SCI_JAR" META-INF/services/jakarta.servlet.ServletContainerInitializer | tr -d '\r')"
[[ "$service_value" == 'br.com.asillos.migration.integration.validation.ValidatorServletContainerInitializer' ]] ||
  fail 'descritor de serviço do SCI aponta para classe inesperada'

war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
source_commit="$(git -C "$ROOT" rev-parse HEAD)"
working_tree=true
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] && working_tree=false

if [[ "$WRITE_EVIDENCE" == true ]]; then
  mkdir -p "$(dirname "$EVIDENCE")"
  cat >"$EVIDENCE" <<EOF
{
  "schema": "wildfly-migration-cp3h-packaging-audit/v1",
  "checkpoint": "CP-3H",
  "activity": "3.39",
  "sourceCommit": "$source_commit",
  "workingTree": $working_tree,
  "warSha256": "$war_sha256",
  "containerApis": "absent-from-war",
  "log4j1AndBridge": "absent",
  "tiles": "absent",
  "commonsFileUpload1": "absent",
  "reflectionsAndScanners": "absent",
  "xmlApis": "absent",
  "geronimoStax": "absent",
  "ojdbc7": "absent",
  "sciInternalJar": "validated",
  "sciServiceDescriptor": "validated",
  "validatorPlacement": "validated",
  "result": "passed"
}
EOF
else
  [[ -f "$EVIDENCE" ]] || fail "evidência ausente: ${EVIDENCE#"$ROOT/"}"
  for marker in \
    '"schema": "wildfly-migration-cp3h-packaging-audit/v1"' \
    '"activity": "3.39"' \
    '"workingTree": false' \
    '"containerApis": "absent-from-war"' \
    '"sciInternalJar": "validated"' \
    '"sciServiceDescriptor": "validated"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$EVIDENCE" || fail "evidência não contém: $marker"
  done
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$EVIDENCE" ||
    fail 'checksum do WAR diverge da evidência de auditoria'
  evidence_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$EVIDENCE" | head -n 1)"
  [[ -n "$evidence_commit" ]] || fail 'sourceCommit ausente na evidência'
  git -C "$ROOT" cat-file -e "$evidence_commit^{commit}" 2>/dev/null ||
    fail 'sourceCommit da evidência não existe no Git'
fi

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|ORACLE_DB_PASSWORD|password|user-name|connection-url|senha' "$EVIDENCE" 2>/dev/null; then
  fail 'evidência de auditoria contém configuração sensível'
fi

printf 'OK: auditoria CP-3H/3.39 rejeita dependências proibidas, APIs no WAR e valida o SCI interno\n'
