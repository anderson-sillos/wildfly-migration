#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false
CLEANUP_REQUIRED=false
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3b-oracle.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3b-oracle.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO] [--non-interactive]

Exige os resultados H2 do mesmo diretório, reconstrói o mesmo WAR e valida
MyBatis 3.5.19 e os 14 contratos no Oracle 19c. Remove somente LAB-SMOKE-*.
USAGE
}

fail() {
  printf 'FALHA qualificação Oracle CP-3B: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ "$CLEANUP_REQUIRED" == true ]]; then
    "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
      cleanup-smokes --java 17 --env "$ENV_FILE" >/dev/null 2>&1 || true
  fi
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3b-oracle.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2
      ;;
  esac
}
trap cleanup EXIT

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
H2_MYBATIS_RESULT="$RESULT_DIRECTORY/cp-3b-mybatis-ci-h2.json"
H2_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-3b-ci-h2.json"
H2_LOGGING_RESULT="$RESULT_DIRECTORY/cp-3b-logging-ci-h2.json"
ORACLE_MYBATIS_RESULT="$RESULT_DIRECTORY/cp-3b-mybatis-oracle.json"
ORACLE_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-3b-oracle.json"
ORACLE_LOGGING_RESULT="$RESULT_DIRECTORY/cp-3b-logging-oracle.json"

for portable_result in \
  "$H2_MYBATIS_RESULT" \
  "$H2_CONTRACT_RESULT" \
  "$H2_LOGGING_RESULT"; do
  [[ -f "$portable_result" ]] ||
    fail "execute qualify-cp-3b-h2.sh antes da qualificação Oracle"
done
cp "$H2_MYBATIS_RESULT" "$TEMP_DIRECTORY/mybatis-ci-h2.json"
cp "$H2_CONTRACT_RESULT" "$TEMP_DIRECTORY/contract-ci-h2.json"
cp "$H2_LOGGING_RESULT" "$TEMP_DIRECTORY/logging-ci-h2.json"

doctor_arguments=(CP-3B --profile oracle --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_arguments+=(--non-interactive)
fi

"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_arguments[@]}"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  verify --java 17 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 17 --env "$ENV_FILE"
CLEANUP_REQUIRED=true

"$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
  --profile oracle --env "$ENV_FILE"
install -d -m 0755 "$RESULT_DIRECTORY"
cp "$TEMP_DIRECTORY/mybatis-ci-h2.json" "$H2_MYBATIS_RESULT"
cp "$TEMP_DIRECTORY/contract-ci-h2.json" "$H2_CONTRACT_RESULT"
cp "$TEMP_DIRECTORY/logging-ci-h2.json" "$H2_LOGGING_RESULT"
"$REPOSITORY_ROOT/scripts/smoke-cp-3b-datasource.sh" \
  --profile oracle \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$ORACLE_CONTRACT_RESULT" \
  --logging-result "$ORACLE_LOGGING_RESULT" \
  --preserve-oracle-smokes
"$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  --java 17 \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$ORACLE_MYBATIS_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-3b.sh" \
  --war "$WAR_FILE" \
  --h2-result "$H2_MYBATIS_RESULT" \
  --h2-contract "$H2_CONTRACT_RESULT" \
  --h2-logging-result "$H2_LOGGING_RESULT" \
  --oracle-result "$ORACLE_MYBATIS_RESULT" \
  --oracle-contract "$ORACLE_CONTRACT_RESULT" \
  --oracle-logging-result "$ORACLE_LOGGING_RESULT"

"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 17 --env "$ENV_FILE"
CLEANUP_REQUIRED=false

printf 'OK: qualificação Oracle CP-3B concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
