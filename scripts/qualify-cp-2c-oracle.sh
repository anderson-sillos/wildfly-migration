#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-2c-oracle.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO]

Executa a qualificação Oracle completa do CP-2C e remove somente os registros
transitórios LAB-SMOKE-* depois de preservar os relatórios sanitizados.
USAGE
}

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
      usage >&2
      exit 2
      ;;
  esac
done

WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
CONTRACT_RESULT="$RESULT_DIRECTORY/cp-2c-oracle.json"
PERSISTENCE_RESULT="$RESULT_DIRECTORY/cp-2c-oracle-persistence.json"

"$REPOSITORY_ROOT/scripts/doctor.sh" \
  CP-2C --profile oracle --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  verify --java 8 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/build-cp-2c.sh" \
  --profile oracle --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh" \
  --profile oracle \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$PERSISTENCE_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c.sh" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT" \
  --oracle-persistence-result "$PERSISTENCE_RESULT"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  cleanup-smokes --java 8 --env "$ENV_FILE"

printf 'OK: qualificação Oracle CP-2C concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
