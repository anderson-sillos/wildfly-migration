#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
PROFILE=""
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
RESULT_FILE=""
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3i-persistence.XXXXXXXX)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3i-persistence.sh --profile ci-h2|oracle \
    [--env ARQUIVO] [--war ARQUIVO] [--result ARQUIVO]

Executa o probe JDBC da atividade 3.41 sem alterar o schema oficial. O perfil
ci-h2 usa H2 em memória; o perfil oracle exige Oracle 19c e ojdbc17 externo.
USAGE
}

fail() {
  printf 'FALHA CP-3I/3.41: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3i-persistence.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2 ;;
  esac
}
trap cleanup EXIT

read_env_value() {
  awk -F= -v wanted="$1" '
    $1 == wanted {
      value = substr($0, index($0, "=") + 1)
      sub(/^"/, "", value); sub(/"$/, "", value)
      sub(/^'\''/, "", value); sub(/'\''$/, "", value)
      print value
      found++
    }
    END { if (found != 1) exit 1 }
  ' "$2"
}

configuration_value() {
  local key="$1"
  local exported
  exported="$(printenv "$key" 2>/dev/null || true)"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    read_env_value "$key" "$ENV_FILE" || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || fail '--profile exige ci-h2 ou oracle'; PROFILE="$2"; shift 2 ;;
    --env) [[ $# -ge 2 ]] || fail '--env exige um arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --result) [[ $# -ge 2 ]] || fail '--result exige um arquivo'; RESULT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ "$PROFILE" == 'ci-h2' || "$PROFILE" == 'oracle' ]] ||
  fail 'informe --profile ci-h2 ou oracle'
[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
if [[ "$PROFILE" == 'oracle' && ! -f "$ENV_FILE" ]]; then
  fail "arquivo .env ausente: $ENV_FILE"
fi

JAVA_HOME_VALUE="$(configuration_value JAVA21_HOME)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$JAVA_HOME_VALUE/bin/javac" ]] ||
  fail 'JAVA21_HOME não aponta para um JDK completo'

MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"
H2_JAR_VALUE="$(configuration_value H2_JAR)"
OJDBC17_JAR_VALUE="$(configuration_value OJDBC17_JAR)"
OJDBC17_SHA256_VALUE="$(configuration_value OJDBC17_SHA256)"
if [[ "$PROFILE" == 'ci-h2' ]]; then
  [[ -f "$H2_JAR_VALUE" ]] || fail 'H2_JAR não aponta para um arquivo existente'
  expected_sha="$(awk -F '\t' '$1 == "h2" { print $6; exit }' "$MANIFEST")"
  [[ "$(sha256sum "$H2_JAR_VALUE" | awk '{print $1}')" == "$expected_sha" ]] ||
    fail 'checksum H2 diverge do manifesto'
  DRIVER_JAR="$H2_JAR_VALUE"
else
  [[ -f "$OJDBC17_JAR_VALUE" ]] || fail 'OJDBC17_JAR não aponta para um arquivo existente'
  [[ "$OJDBC17_SHA256_VALUE" == '96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb' ]] ||
    fail 'OJDBC17_SHA256 diverge do valor aprovado'
  [[ "$(sha256sum "$OJDBC17_JAR_VALUE" | awk '{print $1}')" == "$OJDBC17_SHA256_VALUE" ]] ||
    fail 'checksum ojdbc17 diverge do valor aprovado'
  [[ -n "$(configuration_value ORACLE_DB_URL)" &&
     -n "$(configuration_value ORACLE_DB_USER)" &&
     -n "$(configuration_value ORACLE_DB_PASSWORD)" ]] ||
    fail 'configuração Oracle incompleta'
  DRIVER_JAR="$OJDBC17_JAR_VALUE"
fi

if [[ -z "$RESULT_FILE" ]]; then
  RESULT_FILE="$ROOT/migration/evidence/CP-3I/persistence-$PROFILE.json"
fi
mkdir -p "$(dirname "$RESULT_FILE")"
commit_sha="$(git -C "$ROOT" rev-parse HEAD)"
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
"$JAVA_HOME_VALUE/bin/javac" -encoding UTF-8 -d "$TEMP_DIRECTORY" \
  "$ROOT/scripts/ValidateCp3iPersistence.java"

if [[ "$PROFILE" == 'oracle' ]]; then
  ORACLE_DB_URL="$(configuration_value ORACLE_DB_URL)" \
  ORACLE_DB_USER="$(configuration_value ORACLE_DB_USER)" \
  ORACLE_DB_PASSWORD="$(configuration_value ORACLE_DB_PASSWORD)" \
  "$JAVA_HOME_VALUE/bin/java" -cp "$TEMP_DIRECTORY:$DRIVER_JAR" \
    ValidateCp3iPersistence "$PROFILE" "$ROOT" "$RESULT_FILE" \
    "$commit_sha" "$war_sha256" 'java21-wildfly41.0.0'
else
  "$JAVA_HOME_VALUE/bin/java" -cp "$TEMP_DIRECTORY:$DRIVER_JAR" \
    ValidateCp3iPersistence "$PROFILE" "$ROOT" "$RESULT_FILE" \
    "$commit_sha" "$war_sha256" 'java21-wildfly41.0.0'
fi

for marker in \
  '"rollback": "passed"' \
  '"sequence": "passed"' \
  '"pagination": "passed"' \
  '"timestampTimezone": "passed"' \
  '"clob": "passed"' \
  '"blob": "passed"' \
  '"cleanup": "passed"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$RESULT_FILE" || fail "evidência sem: $marker"
done
if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' \
    "$RESULT_FILE"; then
  fail 'evidência contém configuração sensível'
fi

printf 'OK: CP-3I/3.41 %s, evidência em %s\n' "$PROFILE" "$RESULT_FILE"
