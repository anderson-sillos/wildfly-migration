#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false
CLEANUP_REQUIRED=false
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3a-oracle.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3a-oracle.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO] [--non-interactive]

Exige a evidência H2 do mesmo diretório, constrói e audita o mesmo WAR no
perfil Oracle e executa os 14 contratos, estado persistido e sondas de
commit, rollback, TIMESTAMP(6) e BLOB com Java 17. Remove somente LAB-SMOKE-*.
USAGE
}

fail() {
  printf 'FALHA qualificação Oracle CP-3A: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ "$CLEANUP_REQUIRED" == true ]]; then
    "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
      cleanup-smokes --java 17 --env "$ENV_FILE" >/dev/null 2>&1 || true
    CLEANUP_REQUIRED=false
  fi

  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3a-oracle.*)
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
PORTABLE_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-3a-ci-h2.json"
ORACLE_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-3a-oracle.json"
ORACLE_STATE_RESULT="$RESULT_DIRECTORY/cp-3a-oracle-state.json"
ORACLE_PERSISTENCE_RESULT="$RESULT_DIRECTORY/cp-3a-oracle-persistence.json"

[[ -f "$PORTABLE_CONTRACT_RESULT" ]] ||
  fail "execute qualify-cp-3a-h2.sh antes da qualificação Oracle"
PORTABLE_CONTRACT_BACKUP="$TEMP_DIRECTORY/cp-3a-ci-h2.json"
cp "$PORTABLE_CONTRACT_RESULT" "$PORTABLE_CONTRACT_BACKUP"

doctor_arguments=(CP-3A --profile oracle --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_arguments+=(--non-interactive)
fi

"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_arguments[@]}"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  verify --java 17 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 17 --env "$ENV_FILE"
CLEANUP_REQUIRED=true

"$REPOSITORY_ROOT/scripts/build-cp-3a.sh" \
  --profile oracle --env "$ENV_FILE"
install -d -m 0755 "$RESULT_DIRECTORY"
cp "$PORTABLE_CONTRACT_BACKUP" "$PORTABLE_CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/smoke-cp-3a-datasource.sh" \
  --profile oracle \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$ORACLE_CONTRACT_RESULT" \
  --preserve-oracle-smokes
"$REPOSITORY_ROOT/scripts/validate-cp-2d-oracle-state.sh" \
  --java 17 \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$ORACLE_STATE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  --java 17 \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$ORACLE_PERSISTENCE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-3a.sh" \
  --promoted-war "$WAR_FILE" \
  --promoted-contract-result "$PORTABLE_CONTRACT_RESULT" \
  --oracle-contract-result "$ORACLE_CONTRACT_RESULT" \
  --oracle-state-result "$ORACLE_STATE_RESULT" \
  --oracle-persistence-result "$ORACLE_PERSISTENCE_RESULT"

"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 17 --env "$ENV_FILE"
CLEANUP_REQUIRED=false

printf 'OK: qualificação Oracle CP-3A concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
