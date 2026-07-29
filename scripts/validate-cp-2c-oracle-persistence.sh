#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE=""
RESULT_FILE=""
COMPILE_ONLY=false
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2c-oracle.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-2c-oracle-persistence.sh \
    --war ARQUIVO --result ARQUIVO [--env ARQUIVO]
  ./scripts/validate-cp-2c-oracle-persistence.sh \
    --compile-only --war ARQUIVO [--env ARQUIVO]

Executa uma sonda MyBatis externa ao WAR no schema Oracle descartável.
O relatório é sanitizado e não registra URL, usuário ou senha.
O modo --compile-only não exige driver ou configuração Oracle.
USAGE
}

fail() {
  printf 'FALHA CP-2C Oracle: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2c-oracle.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_env_value() {
  local wanted_key="$1"
  local file="$2"
  local line key value result="" count=0

  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted_key" ]] || continue
    value="$(trim "${line#*=}")"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done <"$file"
  (( count == 1 )) || return 1
  printf '%s' "$result"
}

configuration_value() {
  local key="$1"
  local current="${!key:-}"
  if [[ -n "$current" ]]; then
    printf '%s' "$current"
  else
    read_env_value "$key" "$ENV_FILE" || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"
      shift 2
      ;;
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --result)
      [[ $# -ge 2 ]] || fail "--result exige um arquivo"
      RESULT_FILE="$2"
      shift 2
      ;;
    --compile-only)
      COMPILE_ONLY=true
      shift
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

[[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
if [[ "$COMPILE_ONLY" != true && -z "$RESULT_FILE" ]]; then
  fail "resultado não informado"
fi

JAVA8_HOME_VALUE="$(configuration_value JAVA8_HOME)"

[[ -x "$JAVA8_HOME_VALUE/bin/java" &&
   -x "$JAVA8_HOME_VALUE/bin/javac" ]] ||
  fail "JAVA8_HOME não aponta para um JDK completo"

java_version="$("$JAVA8_HOME_VALUE/bin/java" -version 2>&1)"
[[ "$java_version" == *'1.8.0_492'* ]] ||
  fail "a sonda Oracle exige Eclipse Temurin OpenJDK 8u492"

install -d -m 0755 \
  "$TEMP_DIRECTORY/war" \
  "$TEMP_DIRECTORY/classes"
unzip -q "$WAR_FILE" \
  'WEB-INF/classes/*' \
  'WEB-INF/lib/*' \
  -d "$TEMP_DIRECTORY/war"

war_classes="$TEMP_DIRECTORY/war/WEB-INF/classes"
war_libraries="$TEMP_DIRECTORY/war/WEB-INF/lib/*"
probe_classpath="$war_classes:$war_libraries"
"$JAVA8_HOME_VALUE/bin/javac" \
  -encoding UTF-8 \
  -source 1.8 \
  -target 1.8 \
  -cp "$probe_classpath" \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateCp2cOraclePersistence.java"

if [[ "$COMPILE_ONLY" == true ]]; then
  printf 'OK: sonda Oracle CP-2C compilada sem driver ou credenciais\n'
  exit 0
fi

OJDBC7_JAR_VALUE="$(configuration_value OJDBC7_JAR)"
OJDBC7_SHA256_VALUE="$(configuration_value OJDBC7_SHA256)"
ORACLE_DB_URL_VALUE="$(configuration_value ORACLE_DB_URL)"
ORACLE_DB_USER_VALUE="$(configuration_value ORACLE_DB_USER)"
ORACLE_DB_PASSWORD_VALUE="$(configuration_value ORACLE_DB_PASSWORD)"

[[ -f "$OJDBC7_JAR_VALUE" ]] ||
  fail "OJDBC7_JAR não aponta para o driver externo"
[[ -n "$ORACLE_DB_URL_VALUE" &&
   -n "$ORACLE_DB_USER_VALUE" &&
   -n "$ORACLE_DB_PASSWORD_VALUE" ]] ||
  fail "configuração Oracle está incompleta"

expected_ojdbc_sha256="0d34cddb5726232ad4c0e5db731e930c9c75d8f74b9c4aa449799cc43dd3e829"
actual_ojdbc_sha256="$(sha256sum "$OJDBC7_JAR_VALUE" | awk '{print $1}')"
[[ "${OJDBC7_SHA256_VALUE,,}" == "$expected_ojdbc_sha256" &&
   "$actual_ojdbc_sha256" == "$expected_ojdbc_sha256" ]] ||
  fail "ojdbc7 não corresponde ao driver aprovado"

commit_sha="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
  "$JAVA8_HOME_VALUE/bin/java" \
  -Dfile.encoding=UTF-8 \
  -cp "$TEMP_DIRECTORY/classes:$probe_classpath:$OJDBC7_JAR_VALUE" \
  ValidateCp2cOraclePersistence \
  "$REPOSITORY_ROOT" \
  "$RESULT_FILE" \
  "$commit_sha" \
  "$war_sha256"

for marker in \
  '"schema": "wildfly-migration-oracle-persistence/v1"' \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  "\"commit\": \"$commit_sha\"" \
  "\"warSha256\": \"$war_sha256\"" \
  '"runtime": "java8-wildfly26.1.3-ee8"' \
  '"databaseVersion": "19.3.0.0.0"' \
  '"jdbcDriver": "ojdbc7-12.1.0.2.0"' \
  '"mybatisCommit": "passed"' \
  '"mybatisRollback": "passed"' \
  '"timestampRoundTrip": "passed"' \
  '"blobRoundTrip": "passed"' \
  '"transientDataCleanup": "passed"'; do
  grep -Fq "$marker" "$RESULT_FILE" ||
    fail "resultado sanitizado não contém: $marker"
done

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$RESULT_FILE"; then
  fail "resultado contém configuração sensível"
fi

printf 'OK: relatório Oracle CP-2C sanitizado e vinculado ao WAR atual\n'
