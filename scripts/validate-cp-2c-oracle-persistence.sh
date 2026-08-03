#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE=""
RESULT_FILE=""
COMPILE_ONLY=false
JAVA_RELEASE="8"
DRIVER_FAMILY="ojdbc7"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2c-oracle.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-2c-oracle-persistence.sh \
    --war ARQUIVO --result ARQUIVO [--env ARQUIVO]
  ./scripts/validate-cp-2c-oracle-persistence.sh \
    --compile-only --war ARQUIVO [--java 8|17] [--driver ojdbc7|ojdbc17]
    [--env ARQUIVO]

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
    --java)
      [[ $# -ge 2 && ( "$2" == "8" || "$2" == "17" ) ]] ||
        fail "--java exige 8 ou 17"
      JAVA_RELEASE="$2"
      shift 2
      ;;
    --driver)
      [[ $# -ge 2 && ( "$2" == "ojdbc7" || "$2" == "ojdbc17" ) ]] ||
        fail "--driver exige ojdbc7 ou ojdbc17"
      DRIVER_FAMILY="$2"
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

[[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
if [[ "$COMPILE_ONLY" != true && -z "$RESULT_FILE" ]]; then
  fail "resultado não informado"
fi

if [[ "$JAVA_RELEASE" == "17" ]]; then
  JAVA_HOME_VALUE="$(configuration_value JAVA17_HOME)"
  EXPECTED_JAVA_VERSION='17.0.20'
  RUNTIME_IDENTIFIER='java17-wildfly26.1.3-ee8'
else
  JAVA_HOME_VALUE="$(configuration_value JAVA8_HOME)"
  EXPECTED_JAVA_VERSION='1.8.0_492'
  RUNTIME_IDENTIFIER='java8-wildfly26.1.3-ee8'
fi

[[ -x "$JAVA_HOME_VALUE/bin/java" &&
   -x "$JAVA_HOME_VALUE/bin/javac" ]] ||
  fail "JAVA${JAVA_RELEASE}_HOME não aponta para um JDK completo"

java_version="$("$JAVA_HOME_VALUE/bin/java" -version 2>&1)"
[[ "$java_version" == *"$EXPECTED_JAVA_VERSION"* ]] ||
  fail "a sonda Oracle exige a build Java $JAVA_RELEASE aprovada"

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
"$JAVA_HOME_VALUE/bin/javac" \
  -encoding UTF-8 \
  -source "$JAVA_RELEASE" \
  -target "$JAVA_RELEASE" \
  -cp "$probe_classpath" \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateCp2cOraclePersistence.java"

if [[ "$COMPILE_ONLY" == true ]]; then
  printf 'OK: sonda Oracle CP-2C compilada sem driver ou credenciais\n'
  exit 0
fi

if [[ "$DRIVER_FAMILY" == "ojdbc17" ]]; then
  ORACLE_DRIVER_JAR_VALUE="$(configuration_value OJDBC17_JAR)"
  ORACLE_DRIVER_SHA256_VALUE="$(configuration_value OJDBC17_SHA256)"
  ORACLE_DRIVER_VERSION="23.26.2.0.0"
  ORACLE_DRIVER_EXPECTED_SHA256="96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb"
else
  ORACLE_DRIVER_JAR_VALUE="$(configuration_value OJDBC7_JAR)"
  ORACLE_DRIVER_SHA256_VALUE="$(configuration_value OJDBC7_SHA256)"
  ORACLE_DRIVER_VERSION="12.1.0.2.0"
  ORACLE_DRIVER_EXPECTED_SHA256="0d34cddb5726232ad4c0e5db731e930c9c75d8f74b9c4aa449799cc43dd3e829"
fi
ORACLE_DB_URL_VALUE="$(configuration_value ORACLE_DB_URL)"
ORACLE_DB_USER_VALUE="$(configuration_value ORACLE_DB_USER)"
ORACLE_DB_PASSWORD_VALUE="$(configuration_value ORACLE_DB_PASSWORD)"

[[ -f "$ORACLE_DRIVER_JAR_VALUE" ]] ||
  fail "$DRIVER_FAMILY não aponta para o driver externo"
[[ -n "$ORACLE_DB_URL_VALUE" &&
   -n "$ORACLE_DB_USER_VALUE" &&
   -n "$ORACLE_DB_PASSWORD_VALUE" ]] ||
  fail "configuração Oracle está incompleta"

actual_oracle_driver_sha256="$(sha256sum "$ORACLE_DRIVER_JAR_VALUE" | awk '{print $1}')"
[[ "${ORACLE_DRIVER_SHA256_VALUE,,}" == "$ORACLE_DRIVER_EXPECTED_SHA256" &&
   "$actual_oracle_driver_sha256" == "$ORACLE_DRIVER_EXPECTED_SHA256" ]] ||
  fail "$DRIVER_FAMILY não corresponde ao driver aprovado"

commit_sha="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
ORACLE_JDBC_DRIVER_LABEL="$DRIVER_FAMILY" \
ORACLE_JDBC_DRIVER_VERSION="$ORACLE_DRIVER_VERSION" \
  "$JAVA_HOME_VALUE/bin/java" \
  -Dfile.encoding=UTF-8 \
  -cp "$TEMP_DIRECTORY/classes:$probe_classpath:$ORACLE_DRIVER_JAR_VALUE" \
  ValidateCp2cOraclePersistence \
  "$REPOSITORY_ROOT" \
  "$RESULT_FILE" \
  "$commit_sha" \
  "$war_sha256" \
  "$RUNTIME_IDENTIFIER"

for marker in \
  '"schema": "wildfly-migration-oracle-persistence/v1"' \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  "\"commit\": \"$commit_sha\"" \
  "\"sourceCommit\": \"$commit_sha\"" \
  "\"warSha256\": \"$war_sha256\"" \
  "\"runtime\": \"$RUNTIME_IDENTIFIER\"" \
  '"databaseVersion": "19.3.0.0.0"' \
  "\"jdbcDriver\": \"$DRIVER_FAMILY-$ORACLE_DRIVER_VERSION\"" \
  '"mybatisVersion": "3.5.19"' \
  '"mappers": "passed"' \
  '"aliases": "passed"' \
  '"typeHandlers": "passed"' \
  '"reflection": "passed"' \
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
