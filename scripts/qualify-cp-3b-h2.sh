#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3b-h2.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO] [--non-interactive]

Constrói e audita o WAR do CP-3B, exercita MyBatis 3.5.19 no H2 2.4.240
e executa os 14 contratos externos. O resultado é portable-ci.
USAGE
}

fail() {
  printf 'FALHA qualificação H2 CP-3B: %s\n' "$1" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_env_value() {
  local wanted_key="$1"
  local line key value result="" count=0
  [[ -f "$ENV_FILE" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted_key" ]] || continue
    value="$(trim "${line#*=}")"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done <"$ENV_FILE"
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
    --result-directory)
      [[ $# -ge 2 ]] || fail "--result-directory exige um diretório"
      RESULT_DIRECTORY="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
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

WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
MYBATIS_RESULT="$RESULT_DIRECTORY/cp-3b-mybatis-ci-h2.json"
CONTRACT_RESULT="$RESULT_DIRECTORY/cp-3b-ci-h2.json"
LOGGING_RESULT="$RESULT_DIRECTORY/cp-3b-logging-ci-h2.json"
JAVA17_HOME_VALUE="${JAVA17_HOME:-$(read_env_value JAVA17_HOME || true)}"
H2_JAR_VALUE="${H2_JAR:-$(read_env_value H2_JAR || true)}"

[[ -x "$JAVA17_HOME_VALUE/bin/java" && -f "$H2_JAR_VALUE" ]] ||
  fail "JAVA17_HOME e H2_JAR devem apontar para os componentes aprovados"

doctor_arguments=(CP-3B --profile ci-h2 --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_arguments+=(--non-interactive)
fi

"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_arguments[@]}"
"$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
  --profile ci-h2 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/validate-cp-1d-h2.sh" \
  --java-home "$JAVA17_HOME_VALUE" \
  --h2-jar "$H2_JAR_VALUE"
"$REPOSITORY_ROOT/scripts/validate-cp-1e-persistence.sh" \
  --java-home "$JAVA17_HOME_VALUE" \
  --h2-jar "$H2_JAR_VALUE" \
  --war "$WAR_FILE" \
  --result "$MYBATIS_RESULT"
"$REPOSITORY_ROOT/scripts/smoke-cp-3b-datasource.sh" \
  --profile ci-h2 \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT" \
  --logging-result "$LOGGING_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-3a.sh" \
  --promoted-war "$WAR_FILE" \
  --promoted-contract-result "$CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-3b.sh" \
  --war "$WAR_FILE" \
  --h2-result "$MYBATIS_RESULT" \
  --h2-contract "$CONTRACT_RESULT" \
  --h2-logging-result "$LOGGING_RESULT"

printf 'OK: qualificação H2 CP-3B concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
