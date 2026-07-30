#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
PROFILE=""
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/reproduce-cp-2d.sh \
    --profile ci-h2|oracle \
    [--env ARQUIVO]

Reproduz a fase 2 somente a partir de um checkout Git limpo e de configuração
externa. O perfil oracle executa primeiro a trilha H2 exigida pela comparação.
Relatórios derivados ficam sob app/target/ e não são versionados.
USAGE
}

fail() {
  printf 'FALHA reprodução CP-2D: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || fail "--profile exige ci-h2 ou oracle"
      PROFILE="$2"
      shift 2
      ;;
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"
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

case "$PROFILE" in
  ci-h2|oracle)
    ;;
  *)
    fail "--profile deve ser ci-h2 ou oracle"
    ;;
esac

[[ -f "$ENV_FILE" ]] ||
  fail "configuração externa não encontrada"
git -C "$REPOSITORY_ROOT" rev-parse --is-inside-work-tree \
  >/dev/null 2>&1 ||
  fail "diretório não é um checkout Git"

initial_status="$(
  git -C "$REPOSITORY_ROOT" status --porcelain --untracked-files=all
)"
[[ -z "$initial_status" ]] ||
  fail "checkout contém alterações rastreáveis antes da reprodução"

"$REPOSITORY_ROOT/scripts/validate-repository-baseline.sh"
"$REPOSITORY_ROOT/scripts/qualify-cp-2d-h2.sh" \
  --env "$ENV_FILE" \
  --result-directory "$RESULT_DIRECTORY" \
  --non-interactive

oracle_qualification="not-executed"
if [[ "$PROFILE" == "oracle" ]]; then
  "$REPOSITORY_ROOT/scripts/qualify-cp-2d-oracle.sh" \
    --env "$ENV_FILE" \
    --result-directory "$RESULT_DIRECTORY" \
    --non-interactive
  oracle_qualification="passed"
fi

war_file="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
"$REPOSITORY_ROOT/scripts/validate-cp-2d-manifest.sh" \
  --war "$war_file"

final_status="$(
  git -C "$REPOSITORY_ROOT" status --porcelain --untracked-files=all
)"
[[ -z "$final_status" ]] ||
  fail "reprodução alterou arquivos rastreáveis do checkout"

source_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
war_sha256="$(sha256sum "$war_file" | awk '{print $1}')"
tree_sha256="$(
  sha256sum "$REPOSITORY_ROOT/app/target/dependency-tree.txt" |
    awk '{print $1}'
)"
report_file="$RESULT_DIRECTORY/cp-2d-reproduction-$PROFILE.json"
report_temporary="$report_file.tmp.$$"
install -d -m 0755 "$RESULT_DIRECTORY"

if [[ "$PROFILE" == "oracle" ]]; then
  executed_profiles='["ci-h2", "oracle"]'
  qualification="oracle-qualified"
else
  executed_profiles='["ci-h2"]'
  qualification="portable-ci"
fi

{
  printf '{\n'
  printf '  "schema": "wildfly-migration-phase2-reproduction/v1",\n'
  printf '  "checkpoint": "CP-2D",\n'
  printf '  "sourceCommit": "%s",\n' "$source_commit"
  printf '  "warSha256": "%s",\n' "$war_sha256"
  printf '  "mavenTreeSha256": "%s",\n' "$tree_sha256"
  printf '  "requestedProfile": "%s",\n' "$PROFILE"
  printf '  "executedProfiles": %s,\n' "$executed_profiles"
  printf '  "qualification": "%s",\n' "$qualification"
  printf '  "cleanCheckoutBefore": "passed",\n'
  printf '  "cleanCheckoutAfter": "passed",\n'
  printf '  "contractScenarios": 14,\n'
  printf '  "portableCi": "passed",\n'
  printf '  "oracleQualified": "%s",\n' "$oracle_qualification"
  printf '  "externalConfiguration": "used-without-versioning",\n'
  printf '  "result": "passed"\n'
  printf '}\n'
} >"$report_temporary"
mv "$report_temporary" "$report_file"

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$report_file"; then
  fail "relatório de reprodução contém configuração sensível"
fi

printf 'OK: reprodução limpa CP-2D concluída como %s; relatório em %s\n' \
  "$qualification" "$report_file"
