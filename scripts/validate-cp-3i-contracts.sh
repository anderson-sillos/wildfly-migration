#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
EVIDENCE="$ROOT/migration/evidence/CP-3I"
BASELINE="$ROOT/migration/baselines/01-legacy/contract-scenarios.tsv"

fail() {
  printf 'FALHA CP-3I/3.42: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige arquivo'; WAR_FILE="$2"; shift 2 ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3i-contracts.sh [--war ARQUIVO]'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/scripts/qualify-cp-3i-contracts.sh" \
  "$ROOT/migration/steps/CP-3I-contract-comparison.md" \
  "$ROOT/docs/evidence/CP-3I.md" \
  "$BASELINE" \
  "$EVIDENCE/contract-ci-h2.json" \
  "$EVIDENCE/contract-oracle.json"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: $path"
done

if [[ -f "$WAR_FILE" ]]; then
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
else
  war_sha256=""
fi

for report in "$EVIDENCE/contract-ci-h2.json" "$EVIDENCE/contract-oracle.json"; do
  grep -Fq '"qualification": "' "$report" || fail "qualificação ausente: $report"
  grep -Fq '"runtime": "java21-wildfly41.0.0"' "$report" ||
    fail "runtime ausente: $report"
  grep -Fq '"scenarios": {' "$report" || fail "mapa de cenários ausente: $report"
  grep -Fq '"protectedFragments": "passed"' "$report" ||
    fail "cenário moderno ausente: $report"
  for scenario in $(awk -F '\t' 'NR > 1 { print $1 }' "$BASELINE"); do
    grep -Fq "\"$scenario\": \"passed\"" "$report" ||
      fail "cenário do baseline não aprovado em $report: $scenario"
  done
  source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$report" | head -n 1)"
  [[ -n "$source_commit" ]] || fail "sourceCommit ausente: $report"
  git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
    fail "sourceCommit inexistente: $report"
  if [[ -n "$war_sha256" ]]; then
    grep -Fq "\"warSha256\": \"$war_sha256\"" "$report" ||
      fail "WAR divergente: $report"
  fi
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$report"; then
    fail "evidência contém configuração sensível: $report"
  fi
done

grep -Fq '15' "$ROOT/migration/steps/CP-3I-contract-comparison.md" ||
  fail 'runbook não registra os 15 cenários modernos'
printf 'OK: CP-3I/3.42 H2 e Oracle executaram os 14 cenários do baseline mais protectedFragments (15/15)\n'
