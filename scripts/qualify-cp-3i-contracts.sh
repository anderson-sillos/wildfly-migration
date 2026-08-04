#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE=""
ENV_FILE="$ROOT/.env"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
RESULT_FILE=""
DIAGNOSTIC_LOG=""

usage() {
  printf '%s\n' \
    'Uso: ./scripts/qualify-cp-3i-contracts.sh --profile ci-h2|oracle' \
    '  [--env ARQUIVO] [--war ARQUIVO] [--result ARQUIVO] [--diagnostic-log ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3I/3.42: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    --env) [[ $# -ge 2 ]] || fail '--env exige arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige arquivo'; WAR_FILE="$2"; shift 2 ;;
    --result) [[ $# -ge 2 ]] || fail '--result exige arquivo'; RESULT_FILE="$2"; shift 2 ;;
    --diagnostic-log) [[ $# -ge 2 ]] || fail '--diagnostic-log exige arquivo'; DIAGNOSTIC_LOG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == 'ci-h2' || "$PROFILE" == 'oracle' ]] ||
  fail 'informe --profile ci-h2 ou oracle'
[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
if [[ "$PROFILE" == 'oracle' && ! -f "$ENV_FILE" ]]; then
  fail "arquivo .env ausente: $ENV_FILE"
fi
if [[ -z "$RESULT_FILE" ]]; then
  RESULT_FILE="$ROOT/migration/evidence/CP-3I/contract-$PROFILE.json"
fi
if [[ -z "$DIAGNOSTIC_LOG" ]]; then
  DIAGNOSTIC_LOG="$ROOT/app/target/contract-results/cp3i-3.42-$PROFILE-server.log"
fi
mkdir -p "$(dirname "$RESULT_FILE")" "$(dirname "$DIAGNOSTIC_LOG")"

"$ROOT/scripts/smoke-wildfly41-datasource.sh" \
  --profile "$PROFILE" \
  --env "$ENV_FILE" \
  --war "$WAR_FILE" \
  --result "$RESULT_FILE" \
  --diagnostic-log "$DIAGNOSTIC_LOG"

for scenario in $(awk -F '\t' 'NR > 1 { print $1 }' \
    "$ROOT/migration/baselines/01-legacy/contract-scenarios.tsv"); do
  grep -Fq "\"$scenario\": \"passed\"" "$RESULT_FILE" ||
    fail "cenário não aprovado: $scenario"
done
grep -Fq '"protectedFragments": "passed"' "$RESULT_FILE" ||
  fail 'cenário moderno protectedFragments não foi aprovado'
grep -Fq '"qualification": "portable-ci"' "$RESULT_FILE" && [[ "$PROFILE" == 'ci-h2' ]] ||
  { [[ "$PROFILE" == 'oracle' ]] && grep -Fq '"qualification": "oracle-qualified"' "$RESULT_FILE"; } ||
  fail 'qualificação não corresponde ao perfil'
grep -Fq '"runtime": "java21-wildfly41.0.0"' "$RESULT_FILE" ||
  fail 'runtime Java 21/WildFly 41 ausente'
grep -Fq '"scenarios": {' "$RESULT_FILE" ||
  fail 'mapa de cenários não foi registrado'
if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$RESULT_FILE"; then
  fail 'resultado contém configuração sensível'
fi

printf 'OK: CP-3I/3.42 contratos completos %s e comparação-base aprovados\n' "$PROFILE"
