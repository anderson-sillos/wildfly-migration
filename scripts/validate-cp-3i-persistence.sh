#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
EVIDENCE="$ROOT/migration/evidence/CP-3I"

usage() {
  printf '%s\n' 'Uso: ./scripts/validate-cp-3i-persistence.sh [--war ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3I/3.41: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/scripts/ValidateCp3iPersistence.java" \
  "$ROOT/scripts/qualify-cp-3i-persistence.sh" \
  "$ROOT/migration/steps/CP-3I-persistence-semantics.md" \
  "$ROOT/docs/evidence/CP-3I.md" \
  "$EVIDENCE/persistence-ci-h2.json" \
  "$EVIDENCE/persistence-oracle.json"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

if [[ -f "$WAR_FILE" ]]; then
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
else
  war_sha256=""
fi
current_commit="$(git -C "$ROOT" rev-parse HEAD)"

for report in \
  "$EVIDENCE/persistence-ci-h2.json" \
  "$EVIDENCE/persistence-oracle.json"; do
  for marker in \
    '"schema": "wildfly-migration-cp3i-persistence/v1"' \
    '"checkpoint": "CP-3I"' \
    '"activity": "3.41"' \
    '"workingTree": false' \
    '"rollback": "passed"' \
    '"sequence": "passed"' \
    '"pagination": "passed"' \
    '"timestampTimezone": "passed"' \
    '"clob": "passed"' \
    '"blob": "passed"' \
    '"cleanup": "passed"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$report" || fail "evidência sem $marker: ${report##*/}"
  done
  source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$report" | head -n 1)"
  [[ -n "$source_commit" ]] || fail "sourceCommit ausente: ${report##*/}"
  git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
    fail "sourceCommit inexistente: ${report##*/}"
  if [[ -n "$war_sha256" && "$source_commit" == "$current_commit" ]]; then
    grep -Fq "\"warSha256\": \"$war_sha256\"" "$report" ||
      fail "checksum do WAR diverge: ${report##*/}"
  fi
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$report"; then
    fail "evidência contém configuração sensível: ${report##*/}"
  fi
done

printf 'OK: CP-3I/3.41 rollback, sequence, paginação, timestamp/timezone, CLOB, BLOB e limpeza validados\n'
