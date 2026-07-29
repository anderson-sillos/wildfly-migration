#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
CLEANUP_REQUIRED=false
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2d-oracle.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-2d-oracle.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO]

Executa os 14 contratos no Oracle, compara o estado persistido oficial com a
fase 1, repete as sondas MyBatis/rollback/timestamp/BLOB e remove somente os
registros LAB-SMOKE-* ao terminar. Exige o relatório H2 do mesmo diretório.
USAGE
}

cleanup() {
  if [[ "$CLEANUP_REQUIRED" == true ]]; then
    "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
      cleanup-smokes --java 8 --env "$ENV_FILE" >/dev/null 2>&1 || true
    CLEANUP_REQUIRED=false
  fi

  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2d-oracle.*)
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
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --env exige um arquivo\n' >&2
        exit 2
      }
      ENV_FILE="$2"
      shift 2
      ;;
    --result-directory)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --result-directory exige um diretório\n' >&2
        exit 2
      }
      RESULT_DIRECTORY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
PORTABLE_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-2d-ci-h2.json"
ORACLE_CONTRACT_RESULT="$RESULT_DIRECTORY/cp-2d-oracle.json"
ORACLE_STATE_RESULT="$RESULT_DIRECTORY/cp-2d-oracle-state.json"
ORACLE_PERSISTENCE_RESULT="$RESULT_DIRECTORY/cp-2d-oracle-persistence.json"
SUMMARY_RESULT="$RESULT_DIRECTORY/cp-2d-phase-comparison.json"

[[ -f "$PORTABLE_CONTRACT_RESULT" ]] || {
  printf 'FALHA: execute qualify-cp-2d-h2.sh antes da qualificação Oracle\n' >&2
  exit 1
}
PORTABLE_CONTRACT_BACKUP="$TEMP_DIRECTORY/cp-2d-ci-h2.json"
cp "$PORTABLE_CONTRACT_RESULT" "$PORTABLE_CONTRACT_BACKUP"

"$REPOSITORY_ROOT/scripts/doctor.sh" \
  CP-2D --profile oracle --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  verify --java 8 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 8 --env "$ENV_FILE"
CLEANUP_REQUIRED=true

"$REPOSITORY_ROOT/scripts/build-cp-2c.sh" \
  --profile oracle --env "$ENV_FILE"
install -d -m 0755 "$RESULT_DIRECTORY"
cp "$PORTABLE_CONTRACT_BACKUP" "$PORTABLE_CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh" \
  --profile oracle \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$ORACLE_CONTRACT_RESULT" \
  --preserve-oracle-smokes
"$REPOSITORY_ROOT/scripts/validate-cp-2d-oracle-state.sh" \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$ORACLE_STATE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$ORACLE_PERSISTENCE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c.sh" \
  --war "$WAR_FILE" \
  --contract-result "$ORACLE_CONTRACT_RESULT" \
  --oracle-persistence-result "$ORACLE_PERSISTENCE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2d-phase-comparison.sh" \
  --war "$WAR_FILE" \
  --contract-result "$PORTABLE_CONTRACT_BACKUP" \
  --contract-result "$ORACLE_CONTRACT_RESULT" \
  --oracle-state-result "$ORACLE_STATE_RESULT" \
  --oracle-persistence-result "$ORACLE_PERSISTENCE_RESULT" \
  --summary-result "$SUMMARY_RESULT"

"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 8 --env "$ENV_FILE"
CLEANUP_REQUIRED=false

printf 'OK: qualificação Oracle CP-2D concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
