#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
RESULT_FILE="$ROOT/migration/evidence/CP-3H/xml-ci-h2.json"
EXECUTE=false
SKIP_BUILD=false
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3h-xml.XXXXXXXX)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3h-xml.sh [--env ARQUIVO] [--war ARQUIVO]
    [--result ARQUIVO] [--execute] [--skip-build]

Sem --execute, valida somente versões, fontes, fixtures e a evidência
versionada. Com --execute, recompila o perfil Jakarta/Java 21 quando
necessário, regenera os tipos XMLBeans e executa os contratos seguros de
XMLBeans 5.3.0 e dom4j 2.2.0.
USAGE
}

fail() {
  printf 'FALHA CP-3H/3.36: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3h-xml.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2 ;;
  esac
}
trap cleanup EXIT

read_env_value() {
  local wanted="$1" file="$2" line key value result="" count=0
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted" ]] || continue
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done <"$file"
  (( count == 1 )) || return 1
  printf '%s' "$result"
}

configuration_value() {
  local key="$1" exported="${!1:-}"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    read_env_value "$key" "$ENV_FILE" || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) [[ $# -ge 2 ]] || fail '--env exige um arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --result) [[ $# -ge 2 ]] || fail '--result exige um arquivo'; RESULT_FILE="$2"; shift 2 ;;
    --execute) EXECUTE=true; shift ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/app/pom.xml" \
  "$ROOT/app/src/main/resources/xsd/pedido-importacao-v1.xsd" \
  "$ROOT/scripts/ValidateXmlBeans53.java" \
  "$ROOT/scripts/ValidateDom4j22.java" \
  "$ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-invalido-xsd.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-xxe.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-entidades-expansivas.xml" \
  "$ROOT/migration/steps/CP-3H-xml-safe.md" \
  "$RESULT_FILE"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for marker in \
  '<mybatis.version>3.5.19</mybatis.version>' \
  '<xmlbeans.version>5.3.0</xmlbeans.version>' \
  '<dom4j.version>2.2.0</dom4j.version>' \
  '<artifactId>mybatis</artifactId>' \
  '<artifactId>xmlbeans</artifactId>' \
  '<artifactId>dom4j</artifactId>'; do
  grep -Fq "$marker" "$ROOT/app/pom.xml" || fail "POM não contém: $marker"
done

for forbidden in \
  '<artifactId>xml-apis</artifactId>' \
  '<artifactId>geronimo-stax-api_1.0_spec</artifactId>' \
  '<artifactId>stax-api</artifactId>' \
  '<artifactId>ojdbc7</artifactId>'; do
  if grep -Fq "$forbidden" "$ROOT/app/pom.xml"; then
    fail "dependência XML/JDBC legada reapareceu no POM: $forbidden"
  fi
done

if [[ "$EXECUTE" != true ]]; then
  for marker in \
    '"schema": "wildfly-migration-cp3h-xml/v1"' \
    '"activity": "3.36"' \
    '"mybatisVersion": "3.5.19"' \
    '"xmlbeansVersion": "5.3.0"' \
    '"dom4jVersion": "2.2.0"' \
    '"schemaRejection": "passed"' \
    '"xxeRejection": "passed"' \
    '"entityExpansionRejection": "passed"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$RESULT_FILE" || fail "evidência não contém: $marker"
  done
fi

if [[ "$EXECUTE" != true ]]; then
  printf 'OK: CP-3H/3.36 versões, fontes, fixtures e evidência XML validadas\n'
  exit 0
fi

JAVA_HOME_VALUE="$(configuration_value JAVA21_HOME)"
MAVEN_HOME_VALUE="$(configuration_value MAVEN_HOME)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$JAVA_HOME_VALUE/bin/javac" &&
   -x "$JAVA_HOME_VALUE/bin/jar" ]] || fail 'JAVA21_HOME não aponta para um JDK completo'
[[ -x "$MAVEN_HOME_VALUE/bin/mvn" ]] || fail 'MAVEN_HOME não aponta para Maven'

if [[ "$WAR_FILE" != /* ]]; then
  WAR_FILE="$ROOT/$WAR_FILE"
fi
if [[ "$SKIP_BUILD" != true ]]; then
  BUILD_DIRECTORY="$ROOT/app/target/cp3f-jakarta11"
  JAVA_HOME="$JAVA_HOME_VALUE" PATH="$JAVA_HOME_VALUE/bin:$PATH" \
    "$MAVEN_HOME_VALUE/bin/mvn" -B -ntp -f "$ROOT/app/pom.xml" \
    -Pci-h2,cp-3e-jakarta11 -Dmigration.build.directory="$BUILD_DIRECTORY" \
    clean verify >"$TEMP_DIRECTORY/build.out" 2>&1 || {
      tail -80 "$TEMP_DIRECTORY/build.out" >&2
      fail 'build Jakarta/Java 21 não passou'
    }
fi

[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
CLASSES_DIRECTORY="$ROOT/app/target/cp3f-jakarta11/classes"
GENERATED_SOURCES_DIRECTORY="$ROOT/app/target/cp3f-jakarta11/generated-sources"
[[ -f "$CLASSES_DIRECTORY/wildflyMigrationPedido1/PedidoDocument.class" ]] ||
  fail 'classe XMLBeans gerada ausente'
[[ -f "$GENERATED_SOURCES_DIRECTORY/wildflyMigrationPedido1/PedidoDocument.java" ]] ||
  fail 'fonte XMLBeans gerada ausente'

mkdir -p "$TEMP_DIRECTORY/classes" "$(dirname "$RESULT_FILE")"
(cd "$TEMP_DIRECTORY" && "$JAVA_HOME_VALUE/bin/jar" xf "$WAR_FILE" WEB-INF/lib) ||
  fail 'não foi possível extrair WEB-INF/lib do WAR'
for jar_name in xmlbeans-5.3.0.jar dom4j-2.2.0.jar; do
  [[ -f "$TEMP_DIRECTORY/WEB-INF/lib/$jar_name" ]] ||
    fail "$jar_name não foi empacotado"
done
if find "$TEMP_DIRECTORY/WEB-INF/lib" -maxdepth 1 \
    \( -name 'xml-apis-*.jar' -o -name 'geronimo-stax-api_1.0_spec-*.jar' \
       -o -name 'stax-api-*.jar' \) -print -quit | grep -q .; then
  fail 'WAR contém API XML duplicada'
fi

XML_CLASSPATH="$CLASSES_DIRECTORY:$TEMP_DIRECTORY/WEB-INF/lib/*"
"$JAVA_HOME_VALUE/bin/javac" -cp "$XML_CLASSPATH" -d "$TEMP_DIRECTORY/classes" \
  "$ROOT/scripts/ValidateXmlBeans53.java" "$ROOT/scripts/ValidateDom4j22.java"
xmlbeans_output="$($JAVA_HOME_VALUE/bin/java -cp "$TEMP_DIRECTORY/classes:$XML_CLASSPATH" \
  ValidateXmlBeans53 "$ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-invalido-xsd.xml" 2>/dev/null)" ||
  fail 'contrato XMLBeans 5.3.0 falhou'
dom4j_output="$($JAVA_HOME_VALUE/bin/java -cp "$TEMP_DIRECTORY/classes:$XML_CLASSPATH" \
  ValidateDom4j22 "$ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-xxe.xml" \
  "$ROOT/contract-tests/fixtures/xml/pedido-entidades-expansivas.xml" 2>/dev/null)" ||
  fail 'contrato dom4j 2.2.0 falhou'
grep -Fq '"serializationRoundTrip":"passed"' <<<"$xmlbeans_output" ||
  fail 'round-trip XMLBeans não foi comprovado'
grep -Fq '"entityExpansionRejection":"passed"' <<<"$dom4j_output" ||
  fail 'rejeição de entidades dom4j não foi comprovada'

source_commit="$(git -C "$ROOT" rev-parse HEAD)"
working_tree=true
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] && working_tree=false
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
cat >"$RESULT_FILE" <<EOF
{
  "schema": "wildfly-migration-cp3h-xml/v1",
  "checkpoint": "CP-3H",
  "activity": "3.36",
  "qualification": "portable-ci",
  "profile": "ci-h2",
  "sourceCommit": "$source_commit",
  "workingTree": $working_tree,
  "warSha256": "$war_sha256",
  "runtime": "java21-wildfly41.0.0",
  "mybatisVersion": "3.5.19",
  "xmlbeansVersion": "5.3.0",
  "dom4jVersion": "2.2.0",
  "generatedTypes": "passed",
  "validFixture": "passed",
  "schemaRejection": "passed",
  "namespaceRoundTrip": "passed",
  "serializationRoundTrip": "passed",
  "validDocument": "passed",
  "xxeRejection": "passed",
  "entityExpansionRejection": "passed",
  "result": "passed"
}
EOF

printf 'OK: CP-3H/3.36 regenerou XMLBeans 5.3.0 e aprovou XMLBeans/dom4j seguros; evidência em %s\n' \
  "${RESULT_FILE#"$ROOT/"}"
