#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT/migration/evidence/CP-3K/audit.properties"
WAR="$ROOT/app/target/cp3j-java25/wildfly-migration.war"

fail() {
  printf 'FALHA CP-3K/3.54: %s\n' "$1" >&2
  exit 1
}

for path in \
  "$ROOT/scripts/audit-cp-3k.sh" \
  "$ROOT/docs/evidence/CP-3K.md" \
  "$ROOT/docs/cp-3k-reproduction.md" \
  "$REPORT"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done
bash -n "$ROOT/scripts/audit-cp-3k.sh"

for marker in \
  'schema=wildfly-migration-cp3k-audit/v1' \
  'checkpoint=CP-3K' \
  'activity=3.54' \
  'checkpoint.commits=12' \
  'public.tags=2' \
  'final.tag=absent-before-3.55' \
  'pull.requests=9' \
  'secret.scan=passed' \
  'license.scan=passed' \
  'checksum.scan=passed' \
  'dependency.audit=passed' \
  'war.audit=passed' \
  'rollback.audit=passed' \
  'result=passed'; do
  grep -Fxq "$marker" "$REPORT" || fail "evidência sem: $marker"
done
if [[ -f "$WAR" ]]; then
  war_sha256="$(sha256sum "$WAR" | awk '{print $1}')"
  grep -Fxq "war.sha256=$war_sha256" "$REPORT" ||
    fail 'checksum da auditoria diverge do WAR local'
else
  expected_war_sha256="$(sed -n 's/.*"java25": "\([0-9a-f]\{64\}\)".*/\1/p' \
    "$ROOT/migration/evidence/CP-3J/ci-h2-qualification.json" | head -n 1)"
  [[ -n "$expected_war_sha256" ]] ||
    fail 'WAR ausente e checksum CP-3J não disponível'
  grep -Fxq "war.sha256=$expected_war_sha256" "$REPORT" ||
    fail 'checksum da auditoria diverge da evidência CP-3J'
fi
if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url|senha=|DROP USER|DROP SCHEMA' \
    "$REPORT"; then
  fail 'evidência de auditoria contém segredo ou operação destrutiva'
fi
grep -Fq 'PR incremental #30' "$ROOT/docs/codex-handoff.md" ||
  fail 'PR #30 não está no handoff'
grep -Fq 'Reprodução e rollback' "$ROOT/docs/evidence/CP-3K.md" ||
  fail 'rollback não está no relatório consolidado'

printf 'OK: CP-3K/3.54 auditoria de histórico, segurança, proveniência, WAR e rollback validada\n'
