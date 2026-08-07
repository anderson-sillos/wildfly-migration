#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIR="$ROOT/migration/evidence/CP-3K"
REQUIRE_TAG=false

fail() {
  printf 'FALHA CP-3K/3.55: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-tag) REQUIRE_TAG=true; shift ;;
    -h|--help)
      printf '%s\n' 'Uso: ./scripts/validate-cp-3k-closure.sh [--require-tag]'
      exit 0
      ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

for path in \
  "$ROOT/docs/project-conclusion.md" \
  "$ROOT/docs/evidence/CP-3K.md" \
  "$ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" \
  "$EVIDENCE_DIR/reproduction-ci-h2.json" \
  "$EVIDENCE_DIR/reproduction-oracle.json" \
  "$EVIDENCE_DIR/audit.properties" \
  "$EVIDENCE_DIR/closure.properties" \
  "$EVIDENCE_DIR/rollback.properties"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for marker in \
  'schema=wildfly-migration-cp3k-closure/v1' \
  'checkpoint=CP-3K' \
  'activity=3.55' \
  'portable-ci.contract.scenarios=15' \
  'portable-ci.reproduction=passed' \
  'portable-ci.result=passed' \
  'oracle-qualified.contract.scenarios=15' \
  'oracle-qualified.reproduction=passed' \
  'oracle-qualified.result=passed' \
  'audit.result=passed' \
  'rollback.result=verified-by-documentation' \
  'pull-request=30' \
  'squash.subject=checkpoint(CP-3K): complete final destination' \
  'tag=migration/03-final' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE_DIR/closure.properties" ||
    fail "fechamento sem: $marker"
done

for marker in \
  'schema=wildfly-migration-cp3k-rollback/v1' \
  'checkpoint=CP-3K' \
  'rollback.target=CP-3J' \
  'rollback.commit=eac264e003a05f475c817eaa1df2adb687ae11bf' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documentation'; do
  grep -Fxq "$marker" "$EVIDENCE_DIR/rollback.properties" ||
    fail "rollback sem: $marker"
done

tested_commit="$(sed -n 's/^tested.commit=\([0-9a-f]\{40\}\)$/\1/p' \
  "$EVIDENCE_DIR/closure.properties")"
[[ -n "$tested_commit" ]] || fail 'tested.commit ausente ou inválido'
git -C "$ROOT" cat-file -e "$tested_commit^{commit}" 2>/dev/null ||
  fail 'tested.commit não existe no histórico'

closure_sha="$(sed -n 's/^war.sha256=\([0-9a-f]\{64\}\)$/\1/p' \
  "$EVIDENCE_DIR/closure.properties")"
h2_sha="$(sed -n 's/.*"warSha256": "\([0-9a-f]\{64\}\)".*/\1/p' \
  "$EVIDENCE_DIR/reproduction-ci-h2.json" | head -n 1)"
oracle_sha="$(sed -n 's/.*"warSha256": "\([0-9a-f]\{64\}\)".*/\1/p' \
  "$EVIDENCE_DIR/reproduction-oracle.json" | head -n 1)"
audit_sha="$(sed -n 's/^war.sha256=\([0-9a-f]\{64\}\)$/\1/p' \
  "$EVIDENCE_DIR/audit.properties")"
[[ -n "$closure_sha" && "$closure_sha" == "$h2_sha" && \
  "$closure_sha" == "$oracle_sha" && "$closure_sha" == "$audit_sha" ]] ||
  fail 'checksum do WAR diverge entre fechamento, reproduções e auditoria'

grep -Fq -- '- [x] 3.55 Encerrar `CP-3K`' \
  "$ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail 'atividade 3.55 não está concluída'
grep -Fq 'O destino final está aprovado' "$ROOT/docs/evidence/CP-3K.md" ||
  fail 'relatório consolidado não declara a aprovação final'
grep -Fq 'estado aprovado pelas atividades 3.51 a 3.55' \
  "$ROOT/docs/project-conclusion.md" ||
  fail 'conclusão do projeto não inclui o fechamento 3.55'

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url|senha=' \
    "$EVIDENCE_DIR/closure.properties" "$EVIDENCE_DIR/rollback.properties"; then
  fail 'fechamento contém configuração sensível'
fi

if [[ "$REQUIRE_TAG" == true ]]; then
  tag_commit="$(git -C "$ROOT" rev-parse 'refs/tags/migration/03-final^{commit}' 2>/dev/null || true)"
  main_commit="$(git -C "$ROOT" rev-parse 'refs/remotes/origin/main^{commit}' 2>/dev/null || true)"
  [[ -n "$tag_commit" ]] || fail 'tag migration/03-final ausente'
  [[ -n "$main_commit" && "$tag_commit" == "$main_commit" ]] ||
    fail 'tag migration/03-final não aponta para origin/main'
fi

printf 'OK: CP-3K/3.55 evidências H2/Oracle, auditoria, rollback, PR e tag-alvo aprovados\n'
