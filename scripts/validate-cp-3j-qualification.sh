#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$ROOT/migration/evidence/CP-3J"
PROFILE=""

fail() {
  printf 'FALHA CP-3J/3.49: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3j-qualification.sh --profile ci-h2|oracle'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == ci-h2 || "$PROFILE" == oracle ]] || fail 'informe --profile ci-h2 ou oracle'

for runtime in java21-wildfly41 java25-wildfly41; do
  manifest="$ROOT/runtime/phase3/$runtime/runtime-manifest.tsv"
  [[ -f "$manifest" ]] || fail "manifesto ausente: ${manifest#"$ROOT/"}"
  grep -Fq $'temurin-openjdk\t' "$manifest" || fail "OpenJDK ausente no manifesto $runtime"
  grep -Fq $'wildfly-community-41\t41.0.0.Final\t' "$manifest" ||
    fail "WildFly 41 ausente no manifesto $runtime"
  grep -Fq $'h2\t2.4.240\t' "$manifest" || fail "H2 2.4.240 ausente no manifesto $runtime"
done

aggregate="$EVIDENCE_DIR/${PROFILE}-qualification.json"
[[ -f "$aggregate" ]] || fail "agregador ausente: ${aggregate#"$ROOT/"}"
for marker in \
  '"schema": "wildfly-migration-cp3j-qualification/v1"' \
  '"checkpoint": "CP-3J"' \
  '"activity": "3.49"' \
  '"workingTree": false' \
  '"ports": "loopback-only; java21=28121/29121; java25=28125/29125"' \
  '"secrets": "sanitized-and-not-versioned"' \
  '"packaging": "cp-3h-audit-passed-for-both-wars"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$aggregate" || fail "agregador sem: $marker"
done

qualification="portable-ci"
[[ "$PROFILE" == oracle ]] && qualification="oracle-qualified"
grep -Fq "\"qualification\": \"$qualification\"" "$aggregate" ||
  fail "qualificação do agregador não corresponde ao perfil"

for java_version in 21 25; do
  result="$EVIDENCE_DIR/${PROFILE}-java${java_version}-contracts.json"
  log="$EVIDENCE_DIR/${PROFILE}-java${java_version}-wildfly.log"
  [[ -f "$result" ]] || fail "resultado ausente: ${result#"$ROOT/"}"
  [[ -f "$log" ]] || fail "log sanitizado ausente: ${log#"$ROOT/"}"
  grep -Fq "\"qualification\": \"$qualification\"" "$result" ||
    fail "qualificação Java $java_version incorreta"
  grep -Fq "\"runtime\": \"java${java_version}-wildfly41.0.0\"" "$result" ||
    fail "runtime Java $java_version ausente"
  grep -Fq '"protectedFragments": "passed"' "$result" ||
    fail "contrato moderno não aprovado no Java $java_version"
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|0\.0\.0\.0|\[::\]' \
      "$result" "$log"; then
    fail "resultado/log Java $java_version contém segredo ou bind público"
  fi
done

for path in \
  "$ROOT/scripts/qualify-cp-3j.sh" \
  "$ROOT/scripts/smoke-wildfly41-datasource.sh" \
  "$ROOT/scripts/audit-cp-3h-final-packaging.sh" \
  "$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv" \
  "$ROOT/runtime/phase3/java25-wildfly41/runtime-manifest.tsv"; do
  [[ -f "$path" ]] || fail "arquivo do fluxo ausente: ${path#"$ROOT/"}"
done

printf 'OK: CP-3J/3.49 %s validado em OpenJDK 21 e 25, com contratos, empacotamento, portas, segredos e proveniência\n' "$qualification"
