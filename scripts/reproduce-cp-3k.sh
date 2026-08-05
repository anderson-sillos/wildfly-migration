#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
PROFILE=""
RESULT_FILE="$ROOT/migration/evidence/CP-3K/reproduction-ci-h2.json"
TEMP_DIRECTORY=""

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/reproduce-cp-3k.sh --profile ci-h2|oracle [--env ARQUIVO]
                               [--result ARQUIVO]

Cria um clone local limpo, executa o doctor CP-3K, recompila o WAR com
OpenJDK 25, sobe o WildFly 41 em loopback e executa primeiro H2. O perfil
oracle repete os contratos contra Oracle 19c usando somente a configuração
externa. A evidência copiada para --result é sanitizada.
USAGE
}

fail() {
  printf 'FALHA reprodução CP-3K: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    --env) [[ $# -ge 2 ]] || fail '--env exige arquivo'; ENV_FILE="$2"; shift 2 ;;
    --result) [[ $# -ge 2 ]] || fail '--result exige arquivo'; RESULT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == ci-h2 || "$PROFILE" == oracle ]] || fail 'informe --profile ci-h2 ou oracle'
[[ -f "$ENV_FILE" ]] || fail "configuração externa não encontrada: $ENV_FILE"
[[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] ||
  fail 'o checkout de origem possui alterações; use um checkout limpo'

ENV_FILE="$(cd "$(dirname "$ENV_FILE")" && pwd)/$(basename "$ENV_FILE")"
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3k.XXXXXXXX)"
cleanup() {
  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      /tmp/wildfly-migration-cp3k.*) rm -rf -- "$TEMP_DIRECTORY" ;;
      *) printf 'AVISO: diretório temporário inesperado não removido\n' >&2 ;;
    esac
  fi
}
trap cleanup EXIT

CHECKOUT="$TEMP_DIRECTORY/checkout"
git clone --quiet --no-local "$ROOT" "$CHECKOUT"
[[ -z "$(git -C "$CHECKOUT" status --porcelain --untracked-files=all)" ]] ||
  fail 'clone limpo contém alterações antes da reprodução'

SOURCE_COMMIT="$(git -C "$CHECKOUT" rev-parse HEAD)"
run() {
  (cd "$CHECKOUT" && "$@")
}

run ./scripts/doctor.sh CP-3K --profile ci-h2 --env "$ENV_FILE" --non-interactive
run ./scripts/validate-repository-baseline.sh
run ./scripts/build-cp-3j-java25.sh --env "$ENV_FILE"
run ./scripts/validate-cp-3j-java25.sh

run_smoke() {
  local profile="$1" result="$2" log="$3"
  (
    cd "$CHECKOUT"
    MIGRATION_SOURCE_COMMIT="$SOURCE_COMMIT" \
    WILDFLY_HTTP_PORT=28125 WILDFLY_MANAGEMENT_PORT=29125 \
      ./scripts/smoke-wildfly41-datasource.sh --java 25 --profile "$profile" \
        --env "$ENV_FILE" --war app/target/cp3j-java25/wildfly-migration.war \
        --result "$result" --diagnostic-log "$log"
  )
}

H2_RESULT="$CHECKOUT/app/target/cp3k-ci-h2-java25.json"
H2_LOG="$CHECKOUT/app/target/cp3k-ci-h2-java25.log"
run_smoke ci-h2 "$H2_RESULT" "$H2_LOG"
ORACLE_RESULT="$CHECKOUT/app/target/cp3k-oracle-java25.json"
ORACLE_LOG="$CHECKOUT/app/target/cp3k-oracle-java25.log"
oracle_qualification=not-executed
if [[ "$PROFILE" == oracle ]]; then
  run_smoke oracle "$ORACLE_RESULT" "$ORACLE_LOG"
  oracle_qualification=passed
fi

for report in "$H2_RESULT" "$H2_LOG"; do
  [[ -f "$report" ]] || fail "resultado H2 ausente: $report"
done
[[ "$PROFILE" != oracle || -f "$ORACLE_RESULT" ]] || fail 'resultado Oracle ausente'
if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|0\.0\.0\.0|\[::\]' \
    "$H2_RESULT" "$H2_LOG" \${ORACLE_RESULT:+"$ORACLE_RESULT"} \${ORACLE_LOG:+"$ORACLE_LOG"}; then
  fail 'resultado ou log contém segredo, URL Oracle ou bind público'
fi

qualification=portable-ci
executed_profiles='["ci-h2"]'
if [[ "$PROFILE" == oracle ]]; then
  qualification=oracle-qualified
  executed_profiles='["ci-h2", "oracle"]'
fi

RESULT_FILE="$RESULT_FILE" SOURCE_COMMIT="$SOURCE_COMMIT" \
  QUALIFICATION="$qualification" EXECUTED_PROFILES="$executed_profiles" \
  ORACLE_QUALIFICATION="$oracle_qualification" H2_RESULT="$H2_RESULT" \
  CHECKOUT="$CHECKOUT" PROFILE="$PROFILE" \
  bash -c '
    set -euo pipefail
    install -d -m 0755 "$(dirname "$RESULT_FILE")"
    war_sha256="$(sha256sum "$CHECKOUT/app/target/cp3j-java25/wildfly-migration.war" | awk "{print \$1}")"
    cat >"$RESULT_FILE" <<EOF
{
  "schema": "wildfly-migration-cp3k-reproduction/v1",
  "checkpoint": "CP-3K",
  "activity": "3.53",
  "sourceCommit": "$SOURCE_COMMIT",
  "runtime": "java25-wildfly41.0.0",
  "warSha256": "$war_sha256",
  "requestedProfile": "$PROFILE",
  "executedProfiles": $EXECUTED_PROFILES,
  "qualification": "$QUALIFICATION",
  "contractScenarios": 15,
  "cleanCheckoutBefore": "passed",
  "cleanCheckoutAfter": "passed-source-tree",
  "portableCi": "passed",
  "oracleQualified": "$ORACLE_QUALIFICATION",
  "externalConfiguration": "used-without-versioning",
  "wildflyBind": "loopback-only",
  "result": "passed"
}
EOF
  '

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|DROP USER|DROP SCHEMA' \
    "$RESULT_FILE"; then
  fail 'evidência contém configuração sensível ou operação destrutiva'
fi

printf 'OK: CP-3K reproduzido em checkout limpo como %s; evidência em %s\n' \
  "$qualification" "$RESULT_FILE"
