#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
PROFILE=""
WAR_FILE=""
RESULT_FILE=""
DIAGNOSTIC_LOG_FILE=""
TEMP_DIRECTORY=""
RUNTIME_HOME=""
SERVER_PID=""
SERVER_STARTED=false
ORACLE_SMOKES_CREATED=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/smoke-wildfly41-datasource.sh --profile ci-h2|oracle \
    --war ARQUIVO [--env ARQUIVO] [--result ARQUIVO] \
    [--diagnostic-log ARQUIVO]

Executa WildFly 41/Java 21 em loopback, configura java:/jdbc/MigrationDS,
implanta o WAR e executa a suíte HTTP externa. O relatório é sanitizado.
USAGE
}

fail() {
  printf 'FALHA CP-3F WildFly 41: %s\n' "$1" >&2
  exit 1
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_env_value() {
  local wanted="$1" line key value result="" count=0
  [[ -f "$ENV_FILE" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim "${line%$'\r'}")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted" ]] || continue
    value="$(trim "${line#*=}")"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done <"$ENV_FILE"
  (( count == 1 )) || return 1
  printf '%s' "$result"
}

configuration_value() {
  local key="$1"
  local exported="${!key:-}"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    read_env_value "$key" || true
  fi
}

sanitize_log() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$PROFILE" == "oracle" &&
          ( "$line" == *"${ORACLE_DB_URL_VALUE:-}"* ||
            "$line" == *"${ORACLE_DB_USER_VALUE:-}"* ||
            "$line" == *"${ORACLE_DB_PASSWORD_VALUE:-}"* ||
            "$line" == *"jdbc:oracle:"* || "$line" == *"password"* ) ]]; then
      printf '[linha omitida por conter configuração Oracle]\n'
    else
      printf '%s\n' "${line//"$TEMP_DIRECTORY"/<runtime-temporario>}"
    fi
  done
}

cleanup() {
  if [[ -n "$DIAGNOSTIC_LOG_FILE" && -f "$TEMP_DIRECTORY/server.log" ]]; then
    mkdir -p -- "$(dirname "$DIAGNOSTIC_LOG_FILE")"
    sanitize_log <"$TEMP_DIRECTORY/server.log" >"$DIAGNOSTIC_LOG_FILE"
  fi
  if [[ "$ORACLE_SMOKES_CREATED" == true ]]; then
    ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
    ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
      "$ROOT/scripts/oracle-lab-schema.sh" cleanup-smokes --java 21 \
        --java-home "$JAVA_HOME_VALUE" --env "$ENV_FILE" >/dev/null 2>&1 || true
  fi
  if [[ "$SERVER_STARTED" == true && -n "$RUNTIME_HOME" ]]; then
    JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT" \
      --commands=':shutdown' >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]]; then wait "$SERVER_PID" >/dev/null 2>&1 || true; fi
  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      /tmp/wildfly-migration-cp3f41.*) rm -rf -- "$TEMP_DIRECTORY" ;;
      *) printf 'AVISO: diretório temporário inesperado não removido\n' >&2 ;;
    esac
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; PROFILE="$2"; shift 2 ;;
    --env) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; WAR_FILE="$2"; shift 2 ;;
    --result) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; RESULT_FILE="$2"; shift 2 ;;
    --diagnostic-log) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; DIAGNOSTIC_LOG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$PROFILE" == "ci-h2" || "$PROFILE" == "oracle" ]] || fail 'informe --profile ci-h2 ou oracle'
[[ -f "$WAR_FILE" ]] || fail 'WAR não encontrado'
if [[ "$PROFILE" == "oracle" && ! -f "$ENV_FILE" ]]; then
  fail 'arquivo .env não encontrado'
fi

JAVA_HOME_VALUE="$(configuration_value JAVA21_HOME)"
JAVA_ARCHIVE_VALUE="$(configuration_value JAVA21_ARCHIVE)"
WILDFLY_HOME_VALUE="$(configuration_value WILDFLY41_HOME)"
WILDFLY_ARCHIVE_VALUE="$(configuration_value WILDFLY41_ARCHIVE)"
H2_JAR_VALUE="$(configuration_value H2_JAR)"
OJDBC17_JAR_VALUE="$(configuration_value OJDBC17_JAR)"
OJDBC17_SHA256_VALUE="$(configuration_value OJDBC17_SHA256)"
ORACLE_DB_URL_VALUE="$(configuration_value ORACLE_DB_URL)"
ORACLE_DB_USER_VALUE="$(configuration_value ORACLE_DB_USER)"
ORACLE_DB_PASSWORD_VALUE="$(configuration_value ORACLE_DB_PASSWORD)"

[[ -x "$JAVA_HOME_VALUE/bin/java" ]] || fail 'JAVA21_HOME não aponta para um JDK'
[[ -x "$WILDFLY_HOME_VALUE/bin/standalone.sh" &&
   -x "$WILDFLY_HOME_VALUE/bin/jboss-cli.sh" ]] || fail 'WILDFLY41_HOME inválido'
[[ -f "$JAVA_ARCHIVE_VALUE" && -f "$WILDFLY_ARCHIVE_VALUE" ]] ||
  fail 'arquivos de runtime Java 21/WildFly 41 ausentes'

MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"
expected_java_sha256="$(awk -F '\t' '$1 == "temurin-openjdk" {print $6; exit}' "$MANIFEST")"
expected_wildfly_sha256="$(awk -F '\t' '$1 == "wildfly-community-41" {print $6; exit}' "$MANIFEST")"
[[ "$(sha256sum "$JAVA_ARCHIVE_VALUE" | awk '{print $1}')" == "$expected_java_sha256" ]] ||
  fail 'checksum do OpenJDK 21 diverge do manifesto'
[[ "$(sha256sum "$WILDFLY_ARCHIVE_VALUE" | awk '{print $1}')" == "$expected_wildfly_sha256" ]] ||
  fail 'checksum do WildFly 41 diverge do manifesto'
java_version="$("$JAVA_HOME_VALUE/bin/java" -version 2>&1)"
[[ "$java_version" == *'openjdk version "21.0.12"'* &&
   "$java_version" == *'Temurin-21.0.12+8'* ]] || fail 'Temurin 21.0.12+8 não detectado'

if [[ "$PROFILE" == "ci-h2" ]]; then
  [[ -f "$H2_JAR_VALUE" && "$(basename "$H2_JAR_VALUE")" == 'h2-2.4.240.jar' ]] ||
    fail 'H2 2.4.240 não encontrado'
  expected_h2_sha256="$(awk -F '\t' '$1 == "h2" {print $6; exit}' "$MANIFEST")"
  [[ "$(sha256sum "$H2_JAR_VALUE" | awk '{print $1}')" == "$expected_h2_sha256" ]] ||
    fail 'checksum H2 diverge do manifesto'
else
  [[ -f "$OJDBC17_JAR_VALUE" && -n "$ORACLE_DB_URL_VALUE" &&
     -n "$ORACLE_DB_USER_VALUE" && -n "$ORACLE_DB_PASSWORD_VALUE" ]] ||
    fail 'ojdbc17 e credenciais Oracle são obrigatórios'
  [[ "$OJDBC17_SHA256_VALUE" =~ ^[[:xdigit:]]{64}$ ]] || fail 'checksum ojdbc17 inválido'
  [[ "$(sha256sum "$OJDBC17_JAR_VALUE" | awk '{print $1}')" == "${OJDBC17_SHA256_VALUE,,}" ]] ||
    fail 'checksum ojdbc17 divergente'
fi

HTTP_PORT="$(configuration_value WILDFLY_HTTP_PORT)"
MANAGEMENT_PORT="$(configuration_value WILDFLY_MANAGEMENT_PORT)"
HTTP_PORT="${HTTP_PORT:-18080}"
MANAGEMENT_PORT="${MANAGEMENT_PORT:-19990}"
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3f41.XXXXXXXX)"
RUNTIME_HOME="$TEMP_DIRECTORY/wildfly-41.0.0.Final"
cp -a "$WILDFLY_HOME_VALUE/." "$RUNTIME_HOME/"
mkdir -p -- "$RUNTIME_HOME/standalone/log"

if [[ "$PROFILE" == "ci-h2" ]]; then
  module_dir="$RUNTIME_HOME/modules/com/h2database/h2/cp3f/main"
  mkdir -p -- "$module_dir"
  install -m 0644 "$H2_JAR_VALUE" "$module_dir/h2-2.4.240.jar"
  install -m 0644 "$ROOT/runtime/phase3/java21-wildfly41/h2/module.xml" "$module_dir/module.xml"
  PROFILE_FILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/ci-h2.cli"
else
  module_dir="$RUNTIME_HOME/modules/com/oracle/ojdbc17/main"
  mkdir -p -- "$module_dir"
  install -m 0644 "$OJDBC17_JAR_VALUE" "$module_dir/ojdbc17.jar"
  install -m 0644 "$ROOT/runtime/phase3/java21-wildfly41/ojdbc17/module.xml.template" "$module_dir/module.xml"
  PROFILE_FILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/oracle.cli"
fi

if [[ "$PROFILE" == "ci-h2" ]]; then
  JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/standalone.sh" -b 127.0.0.1 \
    -bmanagement 127.0.0.1 -Djboss.http.port="$HTTP_PORT" \
    -Djboss.management.http.port="$MANAGEMENT_PORT" -Dmigration.bootstrap.h2=true \
    >"$TEMP_DIRECTORY/server.log" 2>&1 &
else
  ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
  ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" JAVA_HOME="$JAVA_HOME_VALUE" \
    "$RUNTIME_HOME/bin/standalone.sh" -b 127.0.0.1 -bmanagement 127.0.0.1 \
      -Djboss.http.port="$HTTP_PORT" -Djboss.management.http.port="$MANAGEMENT_PORT" \
      >"$TEMP_DIRECTORY/server.log" 2>&1 &
fi
SERVER_PID="$!"

ready=false
for unused in $(seq 1 90); do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then break; fi
  if JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT" \
      --commands=':read-attribute(name=server-state)' >/dev/null 2>&1; then
    ready=true
    SERVER_STARTED=true
    break
  fi
  sleep 1
done
if [[ "$ready" != true ]]; then
  tail -n 60 "$TEMP_DIRECTORY/server.log" | sanitize_log >&2
  fail 'WildFly 41 não iniciou'
fi

JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
  --controller="127.0.0.1:$MANAGEMENT_PORT" --file="$PROFILE_FILE" \
  >"$TEMP_DIRECTORY/profile.out" 2>&1 || {
    tail -n 60 "$TEMP_DIRECTORY/profile.out" | sanitize_log >&2
    fail "perfil $PROFILE não foi aplicado"
  }
JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
  --controller="127.0.0.1:$MANAGEMENT_PORT" \
  --commands='/subsystem=datasources/data-source=MigrationDS:test-connection-in-pool' \
  >"$TEMP_DIRECTORY/test.out" 2>&1 || fail 'teste do datasource falhou'
grep -Fq '"outcome" => "success"' "$TEMP_DIRECTORY/test.out" || fail 'pool sem sucesso'
grep -Eq '"result" => (\[true\]|true)' "$TEMP_DIRECTORY/test.out" || fail 'pool não confirmou conexão'

JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
  --controller="127.0.0.1:$MANAGEMENT_PORT" --commands="deploy $WAR_FILE --force" \
  >"$TEMP_DIRECTORY/deploy.out" 2>&1 || {
    tail -n 80 "$TEMP_DIRECTORY/deploy.out" | sanitize_log >&2
    tail -n 80 "$TEMP_DIRECTORY/server.log" | sanitize_log >&2
    fail 'WAR não foi implantado'
  }

BASE_URL="http://127.0.0.1:$HTTP_PORT/wildfly-migration"
ready=false
for unused in $(seq 1 60); do
  if curl --silent --show-error --fail "$BASE_URL/health" | grep -Fq 'status=UP'; then
    ready=true
    break
  fi
  sleep 1
done
[[ "$ready" == true ]] || fail 'aplicação Jakarta não ficou saudável'

RESULT_FILE="${RESULT_FILE:-$TEMP_DIRECTORY/contract-$PROFILE.json}"
COMMIT_SHA="$(git -C "$ROOT" rev-parse HEAD)"
SOURCE_COMMIT_SHA="${MIGRATION_SOURCE_COMMIT:-$COMMIT_SHA}"
CONTRACT_CORRELATION="cp3f-contract-$$"
if [[ "$PROFILE" == "oracle" ]]; then ORACLE_SMOKES_CREATED=true; fi
"$ROOT/contract-tests/run.sh" --base-url "$BASE_URL" --profile "$PROFILE" \
  --war "$WAR_FILE" --result "$RESULT_FILE" --commit "$COMMIT_SHA" \
  --source-commit "$SOURCE_COMMIT_SHA" --runtime 'java21-wildfly41.0.0' \
  --correlation-id "$CONTRACT_CORRELATION"
printf 'OK: contratos CP-3F %s concluídos; resultado em %s\n' "$PROFILE" "$RESULT_FILE"
