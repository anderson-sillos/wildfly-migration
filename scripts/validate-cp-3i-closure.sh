#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$ROOT/migration/evidence/CP-3I"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
SKIP_WAR=false

fail() {
  printf 'FALHA CP-3I/3.45: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --skip-war) SKIP_WAR=true; shift ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3i-closure.sh [--war ARQUIVO] [--skip-war]'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/migration/steps/CP-3I-closure.md" \
  "$ROOT/docs/evidence/CP-3I.md" \
  "$EVIDENCE/manifest.properties" \
  "$EVIDENCE/persistence-ci-h2.json" \
  "$EVIDENCE/persistence-oracle.json" \
  "$EVIDENCE/contract-ci-h2.json" \
  "$EVIDENCE/contract-oracle.json" \
  "$EVIDENCE/closure-portable-ci.json" \
  "$EVIDENCE/closure-oracle-qualified.json" \
  "$EVIDENCE/closure.properties" \
  "$EVIDENCE/rollback.properties"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for marker in \
  'schema=wildfly-migration-cp3i-closure/v1' \
  'checkpoint=CP-3I' \
  'portable-ci.contract.scenarios=15' \
  'portable-ci.persistence=passed' \
  'portable-ci.manifest=passed' \
  'portable-ci.result=passed' \
  'oracle-qualified.contract.scenarios=15' \
  'oracle-qualified.persistence=passed' \
  'oracle-qualified.manifest=passed' \
  'oracle-qualified.result=passed' \
  'public.tag=none' \
  'rollback.result=verified-by-documentation' \
  'pull-request=28' \
  'squash.subject=checkpoint(CP-3I): approve Java 21 Jakarta gate' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE/closure.properties" ||
    fail "fechamento não contém: $marker"
done

for marker in \
  'schema=wildfly-migration-cp3i-rollback/v1' \
  'checkpoint=CP-3I' \
  'rollback.target=CP-3H' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documentation'; do
  grep -Fxq "$marker" "$EVIDENCE/rollback.properties" ||
    fail "rollback não contém: $marker"
done

for file in "$EVIDENCE/closure-portable-ci.json" "$EVIDENCE/closure-oracle-qualified.json"; do
  for marker in \
    '"schema": "wildfly-migration-cp3i-closure/v1"' \
    '"checkpoint": "CP-3I"' \
    '"activity": "3.45"' \
    '"workingTree": false' \
    '"contractScenarios": 15' \
    '"contractResult": "passed"' \
    '"persistenceResult": "passed"' \
    '"manifestResult": "passed"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$file" || fail "evidência não contém $marker: ${file##*/}"
  done
  source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$file" | head -n 1)"
  git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
    fail "sourceCommit inexistente: ${file##*/}"
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$file"; then
    fail "evidência contém configuração sensível: ${file##*/}"
  fi
done

if [[ "$SKIP_WAR" != true ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  for file in "$EVIDENCE/closure-portable-ci.json" "$EVIDENCE/closure-oracle-qualified.json"; do
    grep -Fq "\"warSha256\": \"$war_sha256\"" "$file" ||
      fail "checksum do WAR diverge: ${file##*/}"
  done
fi

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=|DROP USER|DROP SCHEMA|git reset --hard|rm -rf' \
    "$ROOT/migration/steps/CP-3I-closure.md" "$EVIDENCE/closure.properties" "$EVIDENCE/rollback.properties"; then
  fail 'fechamento contém configuração sensível ou operação destrutiva'
fi

printf 'OK: CP-3I/3.45 evidências H2/Oracle, manifesto, rollback e ausência de tag pública aprovados\n'
