#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCUMENT="$REPOSITORY_ROOT/docs/phase2-reproduction.md"
DOCUMENTATION_INDEX="$REPOSITORY_ROOT/docs/README.md"
EVIDENCE_DOCUMENT="$REPOSITORY_ROOT/docs/evidence/CP-2D.md"
EXECUTOR="$REPOSITORY_ROOT/scripts/reproduce-cp-2d.sh"
MANIFEST="$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/manifest.properties"
RESULT_FILE="$REPOSITORY_ROOT/migration/evidence/CP-2D/reproduction-oracle.json"

usage() {
  cat <<'USAGE'
Uso: ./scripts/validate-cp-2d-reproduction.sh [--result ARQUIVO]

Valida o procedimento e a evidência sanitizada da reprodução limpa da fase 2.
USAGE
}

fail() {
  printf 'FALHA CP-2D reprodução: %s\n' "$1" >&2
  exit 1
}

property() {
  local key="$1"
  local value

  value="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { sub(/^[^=]*=/, ""); print }' "$MANIFEST"
  )"
  [[ -n "$value" ]] || fail "propriedade ausente no manifesto: $key"
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --result)
      [[ $# -ge 2 ]] || fail "--result exige um arquivo"
      RESULT_FILE="$2"
      shift 2
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
  "$DOCUMENT" \
  "$DOCUMENTATION_INDEX" \
  "$EVIDENCE_DOCUMENT" \
  "$EXECUTOR" \
  "$MANIFEST" \
  "$RESULT_FILE"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

bash -n "$EXECUTOR"

for section in \
  '# Reprodução da fase 2 a partir de checkout limpo' \
  '## 1. Criar o checkout' \
  '## 2. Preparar componentes externos' \
  '## 3. Criar configuração externa' \
  '## 4. Reprodução portátil' \
  '## 5. Reprodução qualificada no Oracle' \
  '## 6. Valores esperados' \
  '## 7. Verificação e limpeza' \
  '## 8. Falhas e rollback da reprodução'; do
  grep -Fq "$section" "$DOCUMENT" ||
    fail "seção obrigatória ausente: $section"
done

for marker in \
  'git switch --detach <commit-exato-do-PR>' \
  'git status --short' \
  'install -m 0600' \
  '--profile ci-h2' \
  '--profile oracle' \
  'O modo Oracle executa primeiro a trilha H2' \
  'sem exigir identidade Git' \
  'não informe credenciais Oracle' \
  'cleanCheckoutBefore' \
  'cleanCheckoutAfter' \
  'não executa rollback de schema'; do
  grep -Fq -- "$marker" "$DOCUMENT" ||
    fail "controle de reprodução ausente: $marker"
done

for marker in \
  'status --porcelain --untracked-files=all' \
  'validate-repository-baseline.sh' \
  'qualify-cp-2d-h2.sh' \
  'qualify-cp-2d-oracle.sh' \
  'validate-cp-2d-manifest.sh' \
  --non-interactive \
  'externalConfiguration' \
  'used-without-versioning'; do
  grep -Fq -- "$marker" "$EXECUTOR" ||
    fail "executor não contém a guarda: $marker"
done

[[ "$(grep -Fc 'status --porcelain --untracked-files=all' "$EXECUTOR")" == "2" ]] ||
  fail "executor não verifica o checkout antes e depois"

source_commit="$(
  sed -n 's/.*"sourceCommit": "\([0-9a-f]*\)".*/\1/p' "$RESULT_FILE"
)"
[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "commit-fonte da reprodução inválido"

war_sha256="$(property war.sha256)"
tree_sha256="$(property maven.tree.sha256)"
scenario_count="$(property contract.scenarioCount)"

for marker in \
  '"schema": "wildfly-migration-phase2-reproduction/v1"' \
  '"checkpoint": "CP-2D"' \
  "\"warSha256\": \"$war_sha256\"" \
  "\"mavenTreeSha256\": \"$tree_sha256\"" \
  '"requestedProfile": "oracle"' \
  '"executedProfiles": ["ci-h2", "oracle"]' \
  '"qualification": "oracle-qualified"' \
  '"cleanCheckoutBefore": "passed"' \
  '"cleanCheckoutAfter": "passed"' \
  "\"contractScenarios\": $scenario_count" \
  '"portableCi": "passed"' \
  '"oracleQualified": "passed"' \
  '"externalConfiguration": "used-without-versioning"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$RESULT_FILE" ||
    fail "resultado não contém: $marker"
done

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$RESULT_FILE" "$DOCUMENT"; then
  fail "documentação ou resultado contém configuração sensível"
fi

grep -Fq \
  '[Reprodução da fase 2](phase2-reproduction.md)' \
  "$DOCUMENTATION_INDEX" ||
  fail "índice não aponta para a reprodução"
grep -Fq '## Reprodução limpa — atividade 2.19' "$EVIDENCE_DOCUMENT" ||
  fail "evidência CP-2D não registra a atividade 2.19"
grep -Fq "$source_commit" "$EVIDENCE_DOCUMENT" ||
  fail "evidência CP-2D não registra o commit reproduzido"

printf 'OK: fase 2 reproduzida de checkout limpo com H2 e Oracle, sem configuração versionada\n'
