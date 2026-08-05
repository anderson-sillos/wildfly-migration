#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
PROFILE=""
WAR_JAVA21="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
WAR_JAVA25="$ROOT/app/target/cp3j-java25/wildfly-migration.war"
RESULT_DIR="$ROOT/migration/evidence/CP-3J"
REUSE_RESULTS=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3j.sh --profile ci-h2|oracle \
    [--env ARQUIVO] [--war-java21 ARQUIVO] [--war-java25 ARQUIVO]
    [--reuse-results]

Executa os contratos externos do CP-3J/3.49 com os WARs produzidos por
OpenJDK 21 e 25. H2 é a trilha portable-ci; Oracle exige credenciais externas
e produz oracle-qualified. O WildFly fica preso a loopback e os relatórios
não registram segredos. --reuse-results apenas recompõe o agregador a partir
de resultados já executados e não é usado pelo CI.
USAGE
}

fail() {
  printf 'FALHA CP-3J/3.49: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    --env) [[ $# -ge 2 ]] || fail '--env exige arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war-java21) [[ $# -ge 2 ]] || fail '--war-java21 exige arquivo'; WAR_JAVA21="$2"; shift 2 ;;
    --war-java25) [[ $# -ge 2 ]] || fail '--war-java25 exige arquivo'; WAR_JAVA25="$2"; shift 2 ;;
    --reuse-results) REUSE_RESULTS=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == ci-h2 || "$PROFILE" == oracle ]] || fail 'informe --profile ci-h2 ou oracle'
[[ -f "$WAR_JAVA21" ]] || fail "WAR Java 21 não encontrado: $WAR_JAVA21"
[[ -f "$WAR_JAVA25" ]] || fail "WAR Java 25 não encontrado: $WAR_JAVA25"
[[ "$PROFILE" != oracle || -f "$ENV_FILE" ]] || fail "arquivo .env ausente: $ENV_FILE"

mkdir -p "$RESULT_DIR"
commit_sha="$(git -C "$ROOT" rev-parse HEAD)"
working_tree=true
tracked_changes="$({
  git -C "$ROOT" diff --name-only
  git -C "$ROOT" diff --cached --name-only
} | sort -u | grep -Ev '^migration/evidence/' || true)"
untracked_changes="$(git -C "$ROOT" ls-files --others --exclude-standard |
  grep -Ev '^migration/evidence/' || true)"
[[ -z "$tracked_changes" && -z "$untracked_changes" ]] && working_tree=false
if [[ "$REUSE_RESULTS" == true ]]; then
  existing_commit="$(sed -n 's/.*"sourceCommit": "\([0-9a-f]\{7,40\}\)".*/\1/p' \
    "$RESULT_DIR/${PROFILE}-java21-contracts.json" | head -n 1)"
  [[ "$existing_commit" =~ ^[0-9a-f]{7,40}$ ]] ||
    fail 'resultado existente sem sourceCommit válido'
  commit_sha="$existing_commit"
fi

run_one() {
  local java_version="$1" war_file="$2" http_port="$3" management_port="$4"
  local result_file="$RESULT_DIR/${PROFILE}-java${java_version}-contracts.json"
  local diagnostic_log="$RESULT_DIR/${PROFILE}-java${java_version}-wildfly.log"
  local source_manifest="java21-wildfly41"
  [[ "$java_version" == 25 ]] && source_manifest="java25-wildfly41"

  if [[ "$REUSE_RESULTS" == false ]]; then
    WILDFLY_HTTP_PORT="$http_port" \
    WILDFLY_MANAGEMENT_PORT="$management_port" \
    MIGRATION_SOURCE_COMMIT="$commit_sha" \
      "$ROOT/scripts/smoke-wildfly41-datasource.sh" \
        --java "$java_version" \
        --profile "$PROFILE" \
        --env "$ENV_FILE" \
        --war "$war_file" \
        --result "$result_file" \
        --diagnostic-log "$diagnostic_log"
  else
    [[ -f "$result_file" && -f "$diagnostic_log" ]] ||
      fail "resultado existente ausente para Java $java_version"
  fi

  for marker in \
    '"qualification": "portable-ci"' \
    '"qualification": "oracle-qualified"' \
    '"runtime": "java' \
    '"protectedFragments": "passed"'; do
    if [[ "$PROFILE" == ci-h2 && "$marker" == '"qualification": "oracle-qualified"' ]]; then
      continue
    fi
    if [[ "$PROFILE" == oracle && "$marker" == '"qualification": "portable-ci"' ]]; then
      continue
    fi
    grep -Fq "$marker" "$result_file" || fail "evidência Java $java_version sem $marker"
  done

  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' \
      "$result_file" "$diagnostic_log"; then
    fail "evidência Java $java_version contém configuração sensível"
  fi
  if grep -Eiq '0\.0\.0\.0|\[::\]' "$diagnostic_log"; then
    fail "WildFly Java $java_version não ficou restrito a loopback"
  fi
  [[ -f "$ROOT/runtime/phase3/$source_manifest/runtime-manifest.tsv" ]] ||
    fail "manifesto de proveniência ausente: $source_manifest"
}

"$ROOT/scripts/audit-cp-3h-final-packaging.sh" --war "$WAR_JAVA21"
"$ROOT/scripts/audit-cp-3h-final-packaging.sh" --war "$WAR_JAVA25"
run_one 21 "$WAR_JAVA21" 28121 29121
run_one 25 "$WAR_JAVA25" 28125 29125

war21_sha256="$(sha256sum "$WAR_JAVA21" | awk '{print $1}')"
war25_sha256="$(sha256sum "$WAR_JAVA25" | awk '{print $1}')"
qualification="portable-ci"
[[ "$PROFILE" == oracle ]] && qualification="oracle-qualified"

cat >"$RESULT_DIR/${PROFILE}-qualification.json" <<EOF
{
  "schema": "wildfly-migration-cp3j-qualification/v1",
  "checkpoint": "CP-3J",
  "activity": "3.49",
  "qualification": "$qualification",
  "profile": "$PROFILE",
  "sourceCommit": "$commit_sha",
  "workingTree": $working_tree,
  "warSha256": {
    "java21": "$war21_sha256",
    "java25": "$war25_sha256"
  },
  "runtime": {
    "java21": "java21-wildfly41.0.0",
    "java25": "java25-wildfly41.0.0"
  },
  "contracts": {
    "java21": "${PROFILE}-java21-contracts.json",
    "java25": "${PROFILE}-java25-contracts.json"
  },
  "ports": "loopback-only; java21=28121/29121; java25=28125/29125",
  "secrets": "sanitized-and-not-versioned",
  "provenance": [
    "runtime/phase3/java21-wildfly41/runtime-manifest.tsv",
    "runtime/phase3/java25-wildfly41/runtime-manifest.tsv"
  ],
  "packaging": "cp-3h-audit-passed-for-both-wars",
  "result": "passed"
}
EOF

printf 'OK: CP-3J/3.49 %s aprovado em OpenJDK 21 e 25; agregador em %s\n' \
  "$qualification" "$RESULT_DIR/${PROFILE}-qualification.json"
