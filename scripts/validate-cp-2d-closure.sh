#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$REPOSITORY_ROOT/.github/workflows/portable.yml"
TASKS="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
EVIDENCE_DOCUMENT="$REPOSITORY_ROOT/docs/evidence/CP-2D.md"
CLOSURE="$REPOSITORY_ROOT/migration/evidence/CP-2D/closure.properties"
MANIFEST="$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/manifest.properties"

fail() {
  printf 'FALHA CP-2D encerramento: %s\n' "$1" >&2
  exit 1
}

property() {
  local file="$1"
  local key="$2"
  local count
  local value

  count="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { count++ } END { print count + 0 }' "$file"
  )"
  [[ "$count" == "1" ]] ||
    fail "propriedade ausente ou duplicada em ${file##*/}: $key"
  value="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { sub(/^[^=]*=/, ""); print }' "$file"
  )"
  [[ -n "$value" ]] ||
    fail "propriedade vazia em ${file##*/}: $key"
  printf '%s' "$value"
}

for path in "$WORKFLOW" "$TASKS" "$EVIDENCE_DOCUMENT" "$MANIFEST"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for marker in \
  'name: portable-ci' \
  'MIGRATION_SOURCE_COMMIT: >-' \
  '${{ github.event.pull_request.head.sha || github.sha }}' \
  'MIGRATION_CHECKPOINT=CP-2D' \
  './scripts/doctor.sh CP-2D --profile ci-h2 --ci' \
  './scripts/build-cp-2c.sh --profile ci-h2' \
  './scripts/validate-cp-2c-oracle-persistence.sh' \
  './scripts/validate-cp-2d-oracle-state.sh' \
  './scripts/validate-cp-2d-phase-comparison.sh' \
  './scripts/validate-cp-2d-manifest.sh' \
  'app/target/contract-results/cp-2d-ci-h2.json' \
  'name: cp-2d-portable-evidence' \
  'app/target/dependency-tree.txt' \
  'retention-days: 14'; do
  grep -Fq -- "$marker" "$WORKFLOW" ||
    fail "workflow portátil não contém: $marker"
done

if grep -Eq \
    'MIGRATION_CHECKPOINT=CP-2C|cp-2c-portable-contract-result|contract-results/cp-2c-ci-h2.json' \
    "$WORKFLOW"; then
  fail "workflow ainda publica resultado com identidade CP-2C"
fi

if grep -Eiq \
    'ORACLE_DB_|jdbc:oracle:|secrets\.' "$WORKFLOW"; then
  fail "workflow portátil não pode receber configuração Oracle"
fi

if ! grep -Fq -- \
    '- [x] 2.20 Encerrar `CP-2D`' "$TASKS"; then
  [[ ! -f "$CLOSURE" ]] ||
    fail "evidência final existe antes da conclusão da tarefa 2.20"
  printf 'OK: candidato de encerramento CP-2D alinhado; gate final ainda pendente\n'
  exit 0
fi

[[ -f "$CLOSURE" ]] ||
  fail "evidência final ausente depois da conclusão da tarefa 2.20"

[[ "$(property "$CLOSURE" schema)" == \
  "wildfly-migration-checkpoint-closure/v1" ]] ||
  fail "schema da evidência final divergente"
[[ "$(property "$CLOSURE" checkpoint)" == "CP-2D" ]] ||
  fail "checkpoint da evidência final divergente"
[[ "$(property "$CLOSURE" pull-request)" == "18" ]] ||
  fail "pull request do fechamento divergente"
[[ "$(property "$CLOSURE" portable.result)" == "passed" ]] ||
  fail "resultado portátil não aprovado"
[[ "$(property "$CLOSURE" oracle.result)" == "passed" ]] ||
  fail "resultado Oracle não aprovado"
[[ "$(property "$CLOSURE" result)" == "passed" ]] ||
  fail "fechamento não aprovado"
[[ "$(property "$CLOSURE" tag)" == \
  "migration/02-java8-wildfly26" ]] ||
  fail "tag pública divergente"
[[ "$(property "$CLOSURE" rollback.tag)" == \
  "migration/01-legacy-baseline" ]] ||
  fail "tag de rollback divergente"
[[ "$(property "$CLOSURE" squash.subject)" == \
  "checkpoint(CP-2D): complete low-impact modernization" ]] ||
  fail "assunto do squash divergente"
[[ "$(property "$CLOSURE" war.sha256)" == \
  "$(property "$MANIFEST" war.sha256)" ]] ||
  fail "WAR do fechamento diverge do manifesto"
[[ "$(property "$CLOSURE" maven.tree.sha256)" == \
  "$(property "$MANIFEST" maven.tree.sha256)" ]] ||
  fail "árvore Maven do fechamento diverge do manifesto"

source_commit="$(property "$CLOSURE" source.commit)"
portable_source_commit="$(
  property "$CLOSURE" portable.source.commit
)"
oracle_source_commit="$(
  property "$CLOSURE" oracle.source.commit
)"
portable_merge_commit="$(
  property "$CLOSURE" portable.merge.commit
)"
portable_run_id="$(property "$CLOSURE" portable.run.id)"

[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "commit-fonte do fechamento inválido"
[[ "$portable_source_commit" == "$source_commit" ]] ||
  fail "CI portátil não usou o commit-fonte do fechamento"
[[ "$oracle_source_commit" == "$source_commit" ]] ||
  fail "Oracle não usou o commit-fonte do fechamento"
[[ "$portable_merge_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail "merge ref testado pelo CI é inválido"
[[ "$portable_run_id" =~ ^[0-9]+$ ]] ||
  fail "ID da execução remota inválido"
[[ "$(property "$CLOSURE" portable.contract.scenarios)" == "14" ]] ||
  fail "CI portátil não aprovou os 14 contratos"
[[ "$(property "$CLOSURE" oracle.contract.scenarios)" == "14" ]] ||
  fail "Oracle não aprovou os 14 contratos"
[[ "$(property "$CLOSURE" portable.run.url)" == \
  "https://github.com/anderson-sillos/wildfly-migration/actions/runs/$portable_run_id" ]] ||
  fail "URL da execução remota divergente"

for marker in \
  '## Encerramento do CP-2D — atividade 2.20' \
  "$source_commit" \
  "$portable_run_id" \
  'checkpoint(CP-2D): complete low-impact modernization' \
  'migration/02-java8-wildfly26' \
  'migration/01-legacy-baseline'; do
  grep -Fq "$marker" "$EVIDENCE_DOCUMENT" ||
    fail "documentação final não contém: $marker"
done

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$CLOSURE" "$EVIDENCE_DOCUMENT"; then
  fail "evidência final contém configuração sensível"
fi

printf 'OK: evidências H2 e Oracle aprovam o mesmo commit-fonte do CP-2D\n'
