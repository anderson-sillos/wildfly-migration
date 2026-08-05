#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
DOCUMENT="$ROOT/docs/cp-3k-reproduction.md"
REPORT="$ROOT/migration/evidence/CP-3K/reproduction-ci-h2.json"
PROFILE=ci-h2

fail() {
  printf 'FALHA CP-3K/3.53: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    -h|--help) printf '%s\n' 'Uso: ./scripts/validate-cp-3k-reproduction.sh [--profile ci-h2|oracle]'; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == ci-h2 || "$PROFILE" == oracle ]] || fail 'perfil inválido'
[[ -f "$DOCUMENT" ]] || fail 'documentação de reprodução ausente'
[[ -f "$ROOT/scripts/reproduce-cp-3k.sh" ]] || fail 'executor ausente'
[[ -f "$ROOT/docs/evidence/CP-3K.md" ]] || fail 'relatório consolidado ausente'

bash -n "$ROOT/scripts/reproduce-cp-3k.sh"
for section in \
  '# Reprodução do destino final CP-3K' \
  '## 1. Preparar os componentes' \
  '## 2. Reprodução portátil' \
  '## 3. Reprodução qualificada no Oracle' \
  '## 4. Validação e limpeza' \
  '## 5. Falhas e rollback'; do
  grep -Fq "$section" "$DOCUMENT" || fail "seção ausente: $section"
done
for marker in \
  'git clone' 'doctor CP-3K' 'OpenJDK 25' 'WildFly Community 41' \
  'H2 2.4.240' 'portable-ci' 'oracle-qualified' \
  'cleanCheckoutBefore' 'cleanCheckoutAfter' 'sem ser copiada' \
  'não altere tags, schema ou usuário Oracle'; do
  grep -Fqi "$marker" "$DOCUMENT" || fail "controle ausente: $marker"
done

[[ -f "$REPORT" ]] || fail "evidência ausente: \${REPORT#"$ROOT/"}"
for marker in \
  '"schema": "wildfly-migration-cp3k-reproduction/v1"' \
  '"checkpoint": "CP-3K"' \
  '"activity": "3.53"' \
  '"runtime": "java25-wildfly41.0.0"' \
  '"contractScenarios": 15' \
  '"cleanCheckoutBefore": "passed"' \
  '"cleanCheckoutAfter": "passed-source-tree"' \
  '"portableCi": "passed"' \
  '"externalConfiguration": "used-without-versioning"' \
  '"wildflyBind": "loopback-only"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$REPORT" || fail "evidência sem: $marker"
done
qualification=portable-ci
[[ "$PROFILE" == oracle ]] && qualification=oracle-qualified
grep -Fq "\"qualification\": \"$qualification\"" "$REPORT" ||
  fail 'qualificação não corresponde ao perfil'
if [[ "$PROFILE" == ci-h2 ]]; then
  grep -Fq '"oracleQualified": "not-executed"' "$REPORT" ||
    fail 'perfil H2 deveria marcar Oracle como não executado'
else
  grep -Fq '"oracleQualified": "passed"' "$REPORT" ||
    fail 'perfil Oracle deveria marcar a qualificação como aprovada'
fi

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|DROP USER|DROP SCHEMA|0\.0\.0\.0|\[::\]' \
    "$DOCUMENT" "$REPORT"; then
  fail 'documentação/evidência contém segredo, operação destrutiva ou bind público'
fi

printf 'OK: CP-3K/3.53 reprodução %s documentada e evidência sanitizada validada\n' "$qualification"
