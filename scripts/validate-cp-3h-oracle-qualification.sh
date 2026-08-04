#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$ROOT/migration/evidence/CP-3H/oracle-qualification.json"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"

usage() {
  printf '%s\n' 'Uso: ./scripts/validate-cp-3h-oracle-qualification.sh [--war ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3H/3.38: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ -f "$EVIDENCE" ]] || fail 'evidência Oracle 3.38 ausente'
for marker in \
  '"schema": "wildfly-migration-cp3h-oracle-qualification/v1"' \
  '"checkpoint": "CP-3H"' \
  '"activity": "3.38"' \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  '"workingTree": false' \
  '"databaseProduct": "Oracle Database 19c' \
  '"databaseVersion": "19.3.0.0.0"' \
  '"releaseUpdate": "19.3.0.0.0"' \
  '"jdbcDriver": "ojdbc17-23.26.2.0.0' \
  '"jvm": "OpenJDK Runtime Environment Temurin-21.0.12+8' \
  '"wildfly": "WildFly 41.0.0.Final (WildFly Core 33.0.0.Final)"' \
  '"jndiName": "java:/jdbc/MigrationDS"' \
  '"contractScenarios": 15' \
  '"contractSuite": "passed"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$EVIDENCE" || fail "evidência não contém: $marker"
done
source_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{40\}\)".*/\1/p' "$EVIDENCE" | head -n 1)"
[[ -n "$source_commit" ]] || fail 'sourceCommit não é um SHA-1 completo'
git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
  fail 'sourceCommit da evidência não existe no Git'
if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|ORACLE_DB_PASSWORD|password|user-name|connection-url|senha' "$EVIDENCE"; then
  fail 'evidência contém configuração sensível'
fi
if [[ -f "$WAR_FILE" ]]; then
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$EVIDENCE" ||
    fail 'checksum do WAR diverge da evidência Oracle'
fi

printf 'OK: evidência Oracle CP-3H/3.38, versão/RU, driver, JVM, WildFly e contratos validada\n'
