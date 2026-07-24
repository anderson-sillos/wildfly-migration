#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
PROFILE=""
TEMP_DIRECTORY=""
RUNTIME_HOME=""
SERVER_PID=""
SERVER_STARTED=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/smoke-wildfly9-datasource.sh --profile ci-h2|oracle [--env ARQUIVO]

Valores já exportados no ambiente prevalecem sobre o arquivo informado.
USAGE
}

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
  done < "$file"

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

cleanup() {
  if [[ "$SERVER_STARTED" == true && -n "$RUNTIME_HOME" ]]; then
    JAVA_HOME="${SELECTED_JAVA_HOME:-}" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:${SELECTED_MANAGEMENT_PORT:-9990}" \
      --commands=':shutdown' >/dev/null 2>&1 || true
  fi

  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]]; then
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi

  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      "${TMPDIR:-/tmp}"/wildfly-migration-datasource.*)
        rm -rf -- "$TEMP_DIRECTORY"
        ;;
      *)
        printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2
        ;;
    esac
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --profile exige ci-h2 ou oracle\n' >&2
        exit 2
      }
      PROFILE="$2"
      shift 2
      ;;
    --env)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --env exige um arquivo\n' >&2
        exit 2
      }
      ENV_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$PROFILE" in
  ci-h2|oracle)
    ;;
  *)
    printf 'FALHA: informe --profile ci-h2 ou --profile oracle\n' >&2
    exit 2
    ;;
esac

WILDFLY9_HOME_VALUE="$(configuration_value WILDFLY9_HOME)"
WILDFLY9_ARCHIVE_VALUE="$(configuration_value WILDFLY9_ARCHIVE)"
HTTP_PORT_VALUE="$(configuration_value WILDFLY_HTTP_PORT)"
MANAGEMENT_PORT_VALUE="$(configuration_value WILDFLY_MANAGEMENT_PORT)"
HTTP_PORT_VALUE="${HTTP_PORT_VALUE:-8080}"
MANAGEMENT_PORT_VALUE="${MANAGEMENT_PORT_VALUE:-9990}"

if [[ ! -x "$WILDFLY9_HOME_VALUE/bin/standalone.sh" ||
      ! -x "$WILDFLY9_HOME_VALUE/bin/jboss-cli.sh" ]]; then
  printf 'FALHA: WILDFLY9_HOME não aponta para uma distribuição completa\n' >&2
  exit 1
fi
if [[ ! -f "$WILDFLY9_ARCHIVE_VALUE" ]]; then
  printf 'FALHA: WILDFLY9_ARCHIVE não foi fornecido\n' >&2
  exit 1
fi

expected_wildfly_checksum="$(
  awk -F '\t' '$1 == "wildfly" { print $6 }' \
    "$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"
)"
actual_wildfly_checksum="$(
  sha256sum "$WILDFLY9_ARCHIVE_VALUE" | awk '{print $1}'
)"
if [[ "$actual_wildfly_checksum" != "$expected_wildfly_checksum" ]]; then
  printf 'FALHA: checksum do WildFly 9 diverge do manifesto\n' >&2
  exit 1
fi

case "$HTTP_PORT_VALUE:$MANAGEMENT_PORT_VALUE" in
  *[!0-9:]*|:|*::*)
    printf 'FALHA: portas do WildFly são inválidas\n' >&2
    exit 1
    ;;
esac
if [[ "$HTTP_PORT_VALUE" == "$MANAGEMENT_PORT_VALUE" ]]; then
  printf 'FALHA: portas HTTP e management devem ser diferentes\n' >&2
  exit 1
fi

if [[ "$PROFILE" == "ci-h2" ]]; then
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_PORTABLE_HOME)"
  H2_JAR_VALUE="$(configuration_value H2_JAR)"
  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" || ! -f "$H2_JAR_VALUE" ]]; then
    printf 'FALHA: Java portátil e H2 são obrigatórios para ci-h2\n' >&2
    exit 1
  fi
  expected_driver_checksum="$(
    awk -F '\t' '$1 == "h2" { print $6 }' \
      "$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
  )"
  actual_driver_checksum="$(sha256sum "$H2_JAR_VALUE" | awk '{print $1}')"
  if [[ "$actual_driver_checksum" != "$expected_driver_checksum" ]]; then
    printf 'FALHA: checksum do H2 diverge do manifesto portátil\n' >&2
    exit 1
  fi
  PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/ci-h2.cli"
else
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_HOME)"
  OJDBC7_JAR_VALUE="$(configuration_value OJDBC7_JAR)"
  OJDBC7_SHA256_VALUE="$(configuration_value OJDBC7_SHA256)"
  ORACLE_DB_URL_VALUE="$(configuration_value ORACLE_DB_URL)"
  ORACLE_DB_USER_VALUE="$(configuration_value ORACLE_DB_USER)"
  ORACLE_DB_PASSWORD_VALUE="$(configuration_value ORACLE_DB_PASSWORD)"

  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" ||
        ! -f "$OJDBC7_JAR_VALUE" ||
        -z "$ORACLE_DB_URL_VALUE" ||
        -z "$ORACLE_DB_USER_VALUE" ||
        -z "$ORACLE_DB_PASSWORD_VALUE" ]]; then
    printf 'FALHA: Java 7u80, ojdbc7 e configuração Oracle são obrigatórios\n' >&2
    exit 1
  fi
  actual_ojdbc7_checksum="$(
    sha256sum "$OJDBC7_JAR_VALUE" | awk '{print $1}'
  )"
  if [[ ! "$OJDBC7_SHA256_VALUE" =~ ^[[:xdigit:]]{64}$ ]] ||
     [[ "$actual_ojdbc7_checksum" != "${OJDBC7_SHA256_VALUE,,}" ]]; then
    printf 'FALHA: checksum do ojdbc7 não foi aprovado\n' >&2
    exit 1
  fi
  PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/oracle.cli"
fi

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-datasource.XXXXXXXX")"
RUNTIME_HOME="$TEMP_DIRECTORY/wildfly-9.0.2.Final"
install -d -m 0755 "$RUNTIME_HOME"
cp -a "$WILDFLY9_HOME_VALUE/." "$RUNTIME_HOME/"
install -d -m 0755 "$RUNTIME_HOME/standalone/log"

if [[ "$PROFILE" == "ci-h2" ]]; then
  module_directory="$RUNTIME_HOME/modules/com/h2database/h2/cp1d/main"
  install -d -m 0755 "$module_directory"
  install -m 0644 "$H2_JAR_VALUE" "$module_directory/h2-1.4.200.jar"
  install -m 0644 "$REPOSITORY_ROOT/runtime/legacy/h2/module.xml" \
    "$module_directory/module.xml"
else
  module_directory="$RUNTIME_HOME/modules/com/oracle/ojdbc7/main"
  install -d -m 0755 "$module_directory"
  install -m 0644 "$OJDBC7_JAR_VALUE" "$module_directory/ojdbc7.jar"
  install -m 0644 \
    "$REPOSITORY_ROOT/runtime/legacy/ojdbc7/module.xml.template" \
    "$module_directory/module.xml"
fi

SELECTED_MANAGEMENT_PORT="$MANAGEMENT_PORT_VALUE"

if [[ "$PROFILE" == "ci-h2" ]]; then
  JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/standalone.sh" \
      -b 127.0.0.1 \
      -bmanagement 127.0.0.1 \
      -Djboss.http.port="$HTTP_PORT_VALUE" \
      -Djboss.management.http.port="$MANAGEMENT_PORT_VALUE" \
      >"$TEMP_DIRECTORY/server.log" 2>&1 &
else
  ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
  ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
  ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
  JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/standalone.sh" \
      -b 127.0.0.1 \
      -bmanagement 127.0.0.1 \
      -Djboss.http.port="$HTTP_PORT_VALUE" \
      -Djboss.management.http.port="$MANAGEMENT_PORT_VALUE" \
      >"$TEMP_DIRECTORY/server.log" 2>&1 &
fi
SERVER_PID="$!"

ready=false
for unused in $(seq 1 60); do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    break
  fi
  if JAVA_HOME="$SELECTED_JAVA_HOME" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
      --commands=':read-attribute(name=server-state)' \
      >/dev/null 2>&1; then
    ready=true
    SERVER_STARTED=true
    break
  fi
  sleep 1
done

if [[ "$ready" != true ]]; then
  printf 'FALHA: WildFly 9 não iniciou no tempo esperado\n' >&2
  if [[ "$PROFILE" == "ci-h2" && -f "$TEMP_DIRECTORY/server.log" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/server.log" |
      sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
  else
    printf 'Detalhes Oracle foram ocultados para não expor configuração interna\n' >&2
  fi
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --file="$PROFILE_FILE" >"$TEMP_DIRECTORY/profile.out" 2>&1; then
  printf 'FALHA: não foi possível aplicar o perfil %s\n' "$PROFILE" >&2
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --commands='/subsystem=datasources/data-source=MigrationDS:test-connection-in-pool' \
    >"$TEMP_DIRECTORY/test.out" 2>&1; then
  printf 'FALHA: teste do datasource %s não concluiu\n' "$PROFILE" >&2
  exit 1
fi

if ! grep -Fq '"outcome" => "success"' "$TEMP_DIRECTORY/test.out" ||
   ! grep -Eq '"result" => (\[true\]|true)' "$TEMP_DIRECTORY/test.out"; then
  printf 'FALHA: pool MigrationDS não confirmou uma conexão no perfil %s\n' \
    "$PROFILE" >&2
  exit 1
fi

configuration="$RUNTIME_HOME/standalone/configuration/standalone.xml"
if [[ "$PROFILE" == "ci-h2" ]]; then
  if grep -Eiq 'jdbc:h2:(tcp|ssl)|AUTO_SERVER|createTcpServer|createWebServer' \
      "$configuration" ||
     grep -Eiq '<(user-name|password)>[^<]+' "$configuration"; then
    printf 'FALHA: perfil H2 expôs listener, console ou credencial\n' >&2
    exit 1
  fi
else
  for expression in \
    '${env.ORACLE_DB_URL}' \
    '${env.ORACLE_DB_USER}' \
    '${env.ORACLE_DB_PASSWORD}'; do
    if ! grep -Fq "$expression" "$configuration"; then
      printf 'FALHA: configuração Oracle não preservou expressões externas\n' >&2
      exit 1
    fi
  done
fi

printf 'OK: datasource %s publicou java:/jdbc/MigrationDS e passou no pool em loopback\n' \
  "$PROFILE"
