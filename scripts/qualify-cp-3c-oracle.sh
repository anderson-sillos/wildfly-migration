#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3c-oracle.sh [--env ARQUIVO] [--result-directory DIRETORIO]
    [--non-interactive]

Executa a qualificação Oracle 19c do CP-3C em host autorizado: ojdbc17,
datasource WildFly 26, transações, timestamps e LOBs. Não registra segredos.
USAGE
}

fail() {
  printf 'FALHA qualificação Oracle CP-3C: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"; shift 2
      ;;
    --result-directory)
      [[ $# -ge 2 ]] || fail "--result-directory exige um diretório"
      RESULT_DIRECTORY="$2"; shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=true; shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

WAR="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
mkdir -p "$RESULT_DIRECTORY"
doctor_args=(CP-3C --profile oracle --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_args+=(--non-interactive)
fi
"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_args[@]}"
"$REPOSITORY_ROOT/scripts/validate-cp-3c-ojdbc17.sh" --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
  verify --java 17 --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
  --profile oracle --env "$ENV_FILE" --ide-rebuild
"$REPOSITORY_ROOT/scripts/smoke-cp-3b-datasource.sh" \
  --profile oracle --env "$ENV_FILE" --war "$WAR" \
  --contract-result "$RESULT_DIRECTORY/cp-3c-contract-oracle.json"
"$REPOSITORY_ROOT/scripts/validate-cp-2c-oracle-persistence.sh" \
  --java 17 --driver ojdbc17 --env "$ENV_FILE" --war "$WAR" \
  --result "$RESULT_DIRECTORY/cp-3c-persistence-oracle.json"

printf 'OK: qualificação Oracle CP-3C concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
