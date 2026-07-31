#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
RESULT_FILE="$REPOSITORY_ROOT/app/target/contract-results/cp-3c-dom4j-ci-h2.json"
JAVA_HOME_VALUE="${JAVA17_HOME:-}"
SKIP_BUILD=false
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3c-dom4j.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3c-dom4j.sh [--env ARQUIVO]
    [--war ARQUIVO] [--result ARQUIVO] [--skip-build]

Constrói o WAR do gate Java 17 e executa o contrato dom4j 2.2.0 para um
documento legítimo, uma tentativa XXE e uma expansão de entidades.
USAGE
}

fail() {
  printf 'FALHA CP-3C dom4j: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3c-dom4j.*)
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
mkdir -p "$TEMP_DIRECTORY/classes" "$(dirname "$RESULT_FILE")"
(cd "$TEMP_DIRECTORY" && "$JAVA_HOME_VALUE/bin/jar" xf "$WAR_FILE" WEB-INF/lib)
[[ -f "$TEMP_DIRECTORY/WEB-INF/lib/dom4j-2.2.0.jar" ]] ||
  fail "dom4j 2.2.0 não foi empacotado"

DOM4J_CLASSPATH="$TEMP_DIRECTORY/WEB-INF/lib/*"
"$JAVA_HOME_VALUE/bin/javac" \
  -cp "$DOM4J_CLASSPATH" \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateDom4j22.java"

"$JAVA_HOME_VALUE/bin/java" \
  -cp "$TEMP_DIRECTORY/classes:$DOM4J_CLASSPATH" \
  ValidateDom4j22 \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-xxe.xml" \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-entidades-expansivas.xml" \
  | tee "$RESULT_FILE"

printf 'OK: CP-3C dom4j 2.2.0 validado; resultado em %s\n' \
  "$RESULT_FILE"
