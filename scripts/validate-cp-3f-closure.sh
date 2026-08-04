#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="$ROOT/migration/evidence/CP-3F"

fail() {
  printf 'FALHA CP-3F/3.30: %s\n' "$1" >&2
  exit 1
}

required=(
  "$EVIDENCE/contract-ci-h2.json"
  "$EVIDENCE/contract-oracle.json"
  "$EVIDENCE/manifest.properties"
  "$EVIDENCE/closure.properties"
  "$EVIDENCE/rollback.properties"
)
for path in "${required[@]}"; do
  [[ -f "$path" ]] || fail "evidência ausente: ${path#"$ROOT/"}"
done

"$ROOT/scripts/validate-cp-3f-namespace.sh"
"$ROOT/scripts/validate-cp-3g-tiles.sh"

for report in "$EVIDENCE/contract-ci-h2.json" "$EVIDENCE/contract-oracle.json"; do
  grep -Fq '"schema": "wildfly-migration-cp3f-contract-result/v1"' "$report" ||
    fail "schema de contrato divergente: ${report##*/}"
  grep -Fq '"sourceCommit": "117427ce659a1e4c134943fa2af7b7d45b6c44ad"' "$report" ||
    fail "commit testado divergente: ${report##*/}"
  grep -Fq '"workingTree": true' "$report" ||
    fail "proveniência workingTree ausente: ${report##*/}"
  grep -Fq '"scenarioCount": 15' "$report" ||
    fail "quantidade de cenários divergente: ${report##*/}"
  grep -Fq '"protectedFragments": "passed"' "$report" ||
    fail "proteção WEB-INF não comprovada: ${report##*/}"
  grep -Fq '"result": "passed"' "$report" ||
    fail "contrato não aprovado: ${report##*/}"
done

for marker in \
  'runtime.java=21.0.12+8' \
  'runtime.wildfly=41.0.0.Final' \
  'runtime.ee=Jakarta-EE-11-Servlet-6.1' \
  'war.tiles=removed' \
  'portable-ci.result=passed' \
  'oracle-qualified.result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE/manifest.properties" ||
    fail "manifesto não contém: $marker"
done

for marker in \
  'portable-ci.contract.scenarios=15' \
  'portable-ci.result=passed' \
  'oracle-qualified.contract.scenarios=15' \
  'oracle-qualified.result=passed' \
  'namespace.audit=passed' \
  'layout.audit=passed' \
  'transient.oracle.data.cleanup=passed' \
  'result=pending-integration-review'; do
  grep -Fxq "$marker" "$EVIDENCE/closure.properties" ||
    fail "fechamento não contém: $marker"
done

grep -Fxq 'rollback.target=CP-3E' "$EVIDENCE/rollback.properties" ||
  fail 'rollback não retorna ao CP-3E'
grep -Fxq 'rollback.databaseMutation=none' "$EVIDENCE/rollback.properties" ||
  fail 'rollback declara mutação indevida no banco'
grep -Fxq 'rollback.result=verified-by-documented-checkout' \
  "$EVIDENCE/rollback.properties" ||
  fail 'rollback não foi validado por checkout documentado'

printf 'OK: CP-3F preparado para fechamento; evidências H2/Oracle e rollback válidos\n'
