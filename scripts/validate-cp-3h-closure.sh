#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$ROOT/migration/evidence/CP-3H"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
SKIP_WAR=false

usage() {
  printf '%s\n' \
    'Uso: ./scripts/validate-cp-3h-closure.sh [--war ARQUIVO] [--skip-war]'
}

fail() {
  printf 'FALHA CP-3H/3.40: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail '--war exige um arquivo'
      WAR_FILE="$2"
      shift 2
      ;;
    --skip-war)
      SKIP_WAR=true
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

for path in \
  "$ROOT/docs/evidence/CP-3H.md" \
  "$ROOT/migration/steps/CP-3H-closure.md" \
  "$EVIDENCE/closure-portable-ci.json" \
  "$EVIDENCE/closure-oracle-qualified.json" \
  "$EVIDENCE/closure.properties" \
  "$EVIDENCE/rollback.properties"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

if [[ "$SKIP_WAR" != true ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
fi

for marker in \
  'schema=wildfly-migration-cp3h-closure/v1' \
  'checkpoint=CP-3H' \
  'portable-ci.contract.scenarios=15' \
  'portable-ci.result=passed' \
  'oracle-qualified.contract.scenarios=15' \
  'oracle-qualified.result=passed' \
  'xml.audit=passed' \
  'dependency.audit=passed' \
  'war.audit=passed' \
  'rollback.result=verified-by-documentation' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE/closure.properties" ||
    fail "fechamento não contém: $marker"
done

for marker in \
  'schema=wildfly-migration-cp3h-rollback/v1' \
  'checkpoint=CP-3H' \
  'rollback.target=CP-3G' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documentation'; do
  grep -Fxq "$marker" "$EVIDENCE/rollback.properties" ||
    fail "rollback não contém: $marker"
done

tested_commit="$(sed -n 's/^tested.commit=//p' "$EVIDENCE/closure.properties" | head -n 1)"
[[ "$tested_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail 'tested.commit não é um SHA-1 completo'
git -C "$ROOT" cat-file -e "$tested_commit^{commit}" 2>/dev/null ||
  fail 'tested.commit não existe no repositório'

rollback_commit="$(sed -n 's/^rollback.commit=//p' "$EVIDENCE/rollback.properties" | head -n 1)"
[[ "$rollback_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail 'rollback.commit não é um SHA-1 completo'
git -C "$ROOT" cat-file -e "$rollback_commit^{commit}" 2>/dev/null ||
  fail 'rollback.commit não existe no repositório'

for report in \
  "$EVIDENCE/closure-portable-ci.json" \
  "$EVIDENCE/closure-oracle-qualified.json"; do
  for marker in \
    '"schema": "wildfly-migration-cp3h-closure/v1"' \
    '"checkpoint": "CP-3H"' \
    '"activity": "3.40"' \
    '"workingTree": false' \
    '"contractScenarios": 15' \
    '"contractResult": "passed"' \
    '"xmlAudit": "passed"' \
    '"dependencyAudit": "passed"' \
    '"warAudit": "passed"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$report" ||
      fail "evidência não contém $marker: ${report##*/}"
  done
  source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$report" | head -n 1)"
  [[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] ||
    fail "sourceCommit inválido: ${report##*/}"
  git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
    fail "sourceCommit não existe: ${report##*/}"
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|ORACLE_DB_PASSWORD|password|user-name|connection-url|senha' "$report"; then
    fail "evidência contém configuração sensível: ${report##*/}"
  fi
done

if [[ "$SKIP_WAR" != true ]]; then
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  current_commit="$(git -C "$ROOT" rev-parse HEAD)"
  for report in \
    "$EVIDENCE/closure-portable-ci.json" \
    "$EVIDENCE/closure-oracle-qualified.json"; do
    source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$report" | head -n 1)"
    [[ "$source_commit" == "$current_commit" ]] || continue
    grep -Fq "\"warSha256\": \"$war_sha256\"" "$report" ||
      fail "checksum do WAR diverge da evidência: ${report##*/}"
  done
fi

"$ROOT/scripts/validate-cp-3h-xml.sh"
"$ROOT/scripts/validate-cp-3h-datasource.sh"
"$ROOT/scripts/validate-cp-3h-oracle-qualification.sh"
if [[ "$SKIP_WAR" == true ]]; then
  "$ROOT/scripts/audit-cp-3h-final-packaging.sh" --skip-war
else
  "$ROOT/scripts/validate-cp-3h-datasource.sh" --war "$WAR_FILE"
  "$ROOT/scripts/validate-cp-3h-oracle-qualification.sh" --war "$WAR_FILE"
  "$ROOT/scripts/audit-cp-3h-final-packaging.sh" --war "$WAR_FILE"
fi

printf 'OK: CP-3H/3.40 encerrado; H2, Oracle, XML, dependências, WAR e rollback validados\n'
