#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-2d-h2.sh \
    [--env ARQUIVO] [--result-directory DIRETORIO] [--non-interactive]

Executa a comparação portátil completa da fase 2 com os 14 contratos
congelados na fase 1. O resultado H2 não qualifica comportamento Oracle.
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
    --non-interactive)
      NON_INTERACTIVE=true
      shift
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
CONTRACT_RESULT="$RESULT_DIRECTORY/cp-2d-ci-h2.json"

doctor_arguments=(CP-2D --profile ci-h2 --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_arguments+=(--non-interactive)
fi
"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_arguments[@]}"
"$REPOSITORY_ROOT/scripts/build-cp-2c.sh" \
  --profile ci-h2 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh" \
  --profile ci-h2 \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2c.sh" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT"
"$REPOSITORY_ROOT/scripts/validate-cp-2d-phase-comparison.sh" \
  --war "$WAR_FILE" \
  --contract-result "$CONTRACT_RESULT"

printf 'OK: comparação H2 CP-2D concluída; relatório em %s\n' \
  "$CONTRACT_RESULT"
