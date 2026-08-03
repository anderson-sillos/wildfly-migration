#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
RESULT_FILE="$REPOSITORY_ROOT/app/target/contract-results/cp-3c-xmlbeans-ci-h2.json"
CLASSES_DIRECTORY="$REPOSITORY_ROOT/app/target/classes"
GENERATED_SOURCES_DIRECTORY="$REPOSITORY_ROOT/app/target/generated-sources"
JAVA_HOME_VALUE="${JAVA17_HOME:-}"
SKIP_BUILD=false
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3c-xmlbeans.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3c-xmlbeans.sh [--env ARQUIVO]
    [--war ARQUIVO] [--result ARQUIVO] [--skip-build]
    [--classes-directory DIRETORIO]
    [--generated-sources-directory DIRETORIO]

Constrói o WAR do gate Java 17, confirma os tipos gerados pelo XMLBeans 5.3.0
e executa o contrato de schema, namespace e serialização sem banco ou WildFly.
USAGE
}

fail() {
  printf 'FALHA CP-3C XMLBeans: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3c-xmlbeans.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

read_env_value() {
  local wanted_key="$1"
  local file="$2"
  local line key value result="" count=0
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted_key" ]] || continue
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"
      shift 2
      ;;
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --result)
      [[ $# -ge 2 ]] || fail "--result exige um arquivo"
      RESULT_FILE="$2"
      shift 2
      ;;
    --classes-directory)
      [[ $# -ge 2 ]] || fail "--classes-directory exige um diretório"
      CLASSES_DIRECTORY="$2"
      shift 2
      ;;
    --generated-sources-directory)
      [[ $# -ge 2 ]] || fail "--generated-sources-directory exige um diretório"
      GENERATED_SOURCES_DIRECTORY="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
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

if [[ -z "$JAVA_HOME_VALUE" ]]; then
  JAVA_HOME_VALUE="$(read_env_value JAVA17_HOME "$ENV_FILE" || true)"
fi
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$JAVA_HOME_VALUE/bin/javac" && \
   -x "$JAVA_HOME_VALUE/bin/jar" ]] ||
  fail "JAVA17_HOME não aponta para um JDK completo"

if [[ "$SKIP_BUILD" != true ]]; then
  "$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
    --profile ci-h2 --env "$ENV_FILE"
fi

[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
[[ -f "$CLASSES_DIRECTORY/wildflyMigrationPedido1/PedidoDocument.class" ]] ||
  fail "classe gerada PedidoDocument ausente em target/classes"
[[ -f "$GENERATED_SOURCES_DIRECTORY/wildflyMigrationPedido1/PedidoDocument.java" ]] ||
  fail "fonte gerada PedidoDocument ausente"

(cd "$TEMP_DIRECTORY" && "$JAVA_HOME_VALUE/bin/jar" xf "$WAR_FILE" WEB-INF/lib)

[[ -f "$TEMP_DIRECTORY/WEB-INF/lib/xmlbeans-5.3.0.jar" ]] ||
  fail "XMLBeans 5.3.0 não foi empacotado"
[[ -f "$TEMP_DIRECTORY/WEB-INF/lib/log4j-api-2.24.2.jar" ]] ||
  fail "a API Log4j transitiva do XMLBeans não foi auditada"
if find "$TEMP_DIRECTORY/WEB-INF/lib" -maxdepth 1 -name 'log4j-core-*.jar' -print -quit | grep -q .; then
  fail "log4j-core não pode entrar no WAR: XMLBeans requer somente a API"
fi

mkdir -p "$TEMP_DIRECTORY/classes" "$(dirname "$RESULT_FILE")"
XMLBEANS_CLASSPATH="$CLASSES_DIRECTORY:$TEMP_DIRECTORY/WEB-INF/lib/*"
"$JAVA_HOME_VALUE/bin/javac" \
  -cp "$XMLBEANS_CLASSPATH" \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateXmlBeans53.java"

"$JAVA_HOME_VALUE/bin/java" \
  -cp "$TEMP_DIRECTORY/classes:$XMLBEANS_CLASSPATH" \
  ValidateXmlBeans53 \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-invalido-xsd.xml" \
  | tee "$RESULT_FILE"

printf 'OK: CP-3C XMLBeans 5.3.0 validado; resultado em %s\n' \
  "$RESULT_FILE"
