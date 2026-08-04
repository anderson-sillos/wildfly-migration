#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/migration/evidence/CP-3I/manifest.properties"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
RUNTIME_MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"

fail() {
  printf 'FALHA CP-3I/3.43: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) [[ $# -ge 2 ]] || fail '--manifest exige um arquivo'; MANIFEST="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3i-manifest.sh [--manifest ARQUIVO] [--war ARQUIVO]'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ -f "$MANIFEST" ]] || fail "manifesto ausente: ${MANIFEST#"$ROOT/"}"
[[ -f "$RUNTIME_MANIFEST" ]] || fail 'manifesto de runtime ausente'

value() {
  local key="$1"
  awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); found=1; exit }
    END { if (!found) exit 1 }' "$MANIFEST"
}

require_value() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(value "$key")" || fail "chave ausente: $key"
  [[ "$actual" == "$expected" ]] || fail "valor inesperado em $key: $actual"
}

for path in \
  "$ROOT/migration/steps/CP-3I-manifest.md" \
  "$ROOT/docs/evidence/CP-3I.md" \
  "$ROOT/migration/evidence/CP-3I/persistence-ci-h2.json" \
  "$ROOT/migration/evidence/CP-3I/persistence-oracle.json" \
  "$ROOT/migration/evidence/CP-3I/contract-ci-h2.json" \
  "$ROOT/migration/evidence/CP-3I/contract-oracle.json" \
  "$ROOT/migration/evidence/CP-3H/xml-ci-h2.json" \
  "$ROOT/migration/evidence/CP-3H/packaging-audit.json"; do
  [[ -f "$path" ]] || fail "evidência ou runbook ausente: ${path#"$ROOT/"}"
done

require_value schema 'wildfly-migration-cp3i-manifest/v1'
require_value checkpoint 'CP-3I'
require_value activity '3.43'
source_commit="$(value sourceCommit)" || fail 'sourceCommit ausente'
[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || fail 'sourceCommit inválido'
git -C "$ROOT" cat-file -e "$source_commit^{commit}" 2>/dev/null ||
  fail 'sourceCommit não existe no histórico Git'
require_value workingTree false
require_value runtime.java '21.0.12+8'
require_value runtime.wildfly '41.0.0.Final'
require_value runtime.ee 'Jakarta-EE-11-Servlet-6.1'
require_value runtime.maven '3.9.16'
require_value runtime.h2 '2.4.240'
require_value runtime.oracle '19.3.0.0.0'
require_value runtime.oracle.driver 'ojdbc17-23.26.2.0.0'
require_value dependency.mybatis '3.5.19'
require_value dependency.xmlbeans '5.3.0'
require_value dependency.dom4j '2.2.0'
require_value dependency.oracleDriver 'server-module-only'
require_value dependency.h2 'runtime-only'
require_value portable-ci.result passed
require_value oracle-qualified.result passed
require_value result passed

for key in \
  runtime.manifest runtime.java.license runtime.java.sha256 \
  runtime.wildfly.license runtime.wildfly.sha256 runtime.h2.license \
  runtime.h2.sha256 runtime.oracle.driver.license runtime.oracle.driver.sha256 \
  war.path war.sha256 war.libraryCount evidence.persistence.h2 \
  evidence.persistence.oracle evidence.contracts.h2 evidence.contracts.oracle \
  evidence.xml evidence.packaging; do
  value "$key" >/dev/null || fail "chave obrigatória ausente: $key"
done

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|secret' "$MANIFEST"; then
  fail 'manifesto contém configuração sensível'
fi

if [[ -f "$WAR_FILE" ]]; then
  expected_sha="$(value war.sha256)"
  actual_sha="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  [[ "$actual_sha" == "$expected_sha" ]] || fail "checksum do WAR diverge: $actual_sha"
  expected_count="$(value war.libraryCount)"
  actual_count="$(jar tf "$WAR_FILE" | awk '/^WEB-INF\/lib\/[^/]+\.jar$/ { count++ } END { print count + 0 }')"
  [[ "$actual_count" == "$expected_count" ]] || fail "quantidade de bibliotecas do WAR diverge: $actual_count"
fi

printf 'OK: CP-3I/3.43 manifesto, runtime, dependências, checksum do WAR e evidências válidos\n'
