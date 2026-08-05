#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$ROOT/migration/evidence/CP-3J"
WAR_JAVA21="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
WAR_JAVA25="$ROOT/app/target/cp3j-java25/wildfly-migration.war"
SKIP_WAR=false

fail() {
  printf 'FALHA CP-3J/3.50: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war-java21) [[ $# -ge 2 ]] || fail '--war-java21 exige arquivo'; WAR_JAVA21="$2"; shift 2 ;;
    --war-java25) [[ $# -ge 2 ]] || fail '--war-java25 exige arquivo'; WAR_JAVA25="$2"; shift 2 ;;
    --skip-war) SKIP_WAR=true; shift ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3j-closure.sh [--war-java21 ARQUIVO] [--war-java25 ARQUIVO] [--skip-war]'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/migration/steps/CP-3J-closure.md" \
  "$ROOT/docs/evidence/CP-3J.md" \
  "$EVIDENCE_DIR/ci-h2-qualification.json" \
  "$EVIDENCE_DIR/oracle-qualification.json" \
  "$EVIDENCE_DIR/closure.properties" \
  "$EVIDENCE_DIR/rollback.properties"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for marker in \
  'schema=wildfly-migration-cp3j-closure/v1' \
  'checkpoint=CP-3J' \
  'portable-ci.java21.contract.scenarios=15' \
  'portable-ci.java25.contract.scenarios=15' \
  'portable-ci.result=passed' \
  'oracle-qualified.java21.contract.scenarios=15' \
  'oracle-qualified.java25.contract.scenarios=15' \
  'oracle-qualified.result=passed' \
  'public.tag=none' \
  'rollback.result=verified-by-documentation' \
  'pull-request=29' \
  'squash.subject=checkpoint(CP-3J): qualify OpenJDK 25' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE_DIR/closure.properties" ||
    fail "fechamento não contém: $marker"
done

for marker in \
  'schema=wildfly-migration-cp3j-rollback/v1' \
  'checkpoint=CP-3J' \
  'rollback.target=CP-3I' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documentation'; do
  grep -Fxq "$marker" "$EVIDENCE_DIR/rollback.properties" ||
    fail "rollback não contém: $marker"
done

for profile in ci-h2 oracle; do
  aggregate="$EVIDENCE_DIR/${profile}-qualification.json"
  qualification="portable-ci"
  [[ "$profile" == oracle ]] && qualification="oracle-qualified"
  for marker in \
    '"schema": "wildfly-migration-cp3j-qualification/v1"' \
    '"checkpoint": "CP-3J"' \
    '"activity": "3.49"' \
    '"workingTree": false' \
    '"result": "passed"' \
    "\"qualification\": \"$qualification\""; do
    grep -Fq "$marker" "$aggregate" || fail "agregador $profile sem: $marker"
  done
  source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{7,40\}\)".*/\1/p' "$aggregate" | head -n 1)"
  [[ "$source_commit" =~ ^[0-9a-f]{7,40}$ ]] || fail "sourceCommit inválido em $profile"
  if ! git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null; then
    [[ "$(git -C "$ROOT" rev-parse --is-shallow-repository 2>/dev/null || true)" == true ]] ||
      fail "sourceCommit inexistente em $profile"
  fi
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$aggregate"; then
    fail "agregador $profile contém configuração sensível"
  fi
done

if [[ "$SKIP_WAR" != true ]]; then
  [[ -f "$WAR_JAVA21" && -f "$WAR_JAVA25" ]] || fail 'WAR Java 21/25 ausente'
  sha21="$(sha256sum "$WAR_JAVA21" | awk '{print $1}')"
  sha25="$(sha256sum "$WAR_JAVA25" | awk '{print $1}')"
  current_commit="$(git -C "$ROOT" rev-parse HEAD)"
  for profile in ci-h2 oracle; do
    aggregate="$EVIDENCE_DIR/${profile}-qualification.json"
    source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{7,40\}\)".*/\1/p' "$aggregate" | head -n 1)"
    [[ "$source_commit" == "$current_commit" ]] || continue
    grep -Fq "\"java21\": \"$sha21\"" "$aggregate" || fail "checksum Java 21 diverge em $profile"
    grep -Fq "\"java25\": \"$sha25\"" "$aggregate" || fail "checksum Java 25 diverge em $profile"
  done
fi

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=|DROP USER|DROP SCHEMA|git reset --hard|rm -rf' \
    "$ROOT/migration/steps/CP-3J-closure.md" "$EVIDENCE_DIR/closure.properties" "$EVIDENCE_DIR/rollback.properties"; then
  fail 'fechamento contém configuração sensível ou operação destrutiva'
fi

printf 'OK: CP-3J/3.50 evidências H2/Oracle, Java 21/25, rollback e ausência de tag pública aprovados\n'
