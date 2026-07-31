#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
PROFILE=""
JAVA_RELEASE="7"
SERVER_RELEASE="9"
WAR_FILE=""
CONTRACT_RESULT_FILE=""
DIAGNOSTIC_LOG_FILE=""
MANUAL_MODE=false
PRESERVE_ORACLE_SMOKES=false
TEMP_DIRECTORY=""
RUNTIME_HOME=""
SERVER_PID=""
SERVER_STARTED=false
ORACLE_SMOKE_CREATED=false
RUNTIME_IDENTIFIER="java7-wildfly9.0.2"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/smoke-wildfly9-datasource.sh --profile ci-h2|oracle \
    [--java 7|8|17] [--server 9|26] [--env ARQUIVO] [--war ARQUIVO] \
    [--contract-result ARQUIVO] [--diagnostic-log ARQUIVO] \
    [--manual] [--preserve-oracle-smokes]

Valores já exportados no ambiente prevalecem sobre o arquivo informado.
Sem --war, valida somente o datasource. Com --war, valida também o fluxo web.
Com --manual, mantém a aplicação ativa em loopback até Ctrl+C; exige --war.
No modo manual, imprime o caminho do log bruto do WildFly.
Com --contract-result, preserva fora do runtime o relatório JSON sanitizado.
Com --diagnostic-log, preserva uma cópia sanitizada do log do servidor.
Com --preserve-oracle-smokes, o perfil Oracle mantém temporariamente apenas
os dados LAB-SMOKE-* para uma sonda externa; o chamador deve limpá-los.
O padrão Java 7 preserva a reprodução histórica; CP-2A deve informar --java 8.
O argumento --server 26 aceita Java 8 ou a tentativa controlada do CP-3A
com Java 17.
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

phase2_manifest_field() {
  local field="$1"
  awk -F '\t' -v wanted_field="$field" '
    NR == 1 {
      for (column = 1; column <= NF; column++) {
        header[$column] = column
      }
      next
    }
    $1 == "temurin-openjdk" {
      print $header[wanted_field]
      found = 1
      exit
    }
    END {
      if (!found) {
        exit 1
      }
    }
  ' "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly9/runtime-manifest.tsv"
}

sanitize_oracle_output() {
  local line sanitized

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "${ORACLE_DB_URL_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_URL_VALUE"* ]] ||
       [[ -n "${ORACLE_DB_USER_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_USER_VALUE"* ]] ||
       [[ -n "${ORACLE_DB_PASSWORD_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_PASSWORD_VALUE"* ]]; then
      printf '[linha omitida por conter configuração Oracle]\n'
      continue
    fi

    case "$line" in
      *jdbc:oracle:*|*ORACLE_DB_*|*connection-url*|*user-name*|\
      *password*|*PASSWORD*)
        printf '[linha omitida por conter configuração Oracle]\n'
        ;;
      *)
        sanitized="${line//"$TEMP_DIRECTORY"/<runtime-temporario>}"
        printf '%s\n' "$sanitized"
        ;;
    esac
  done
}

cleanup() {
  if [[ -n "$DIAGNOSTIC_LOG_FILE" &&
        -n "$TEMP_DIRECTORY" &&
        -f "$TEMP_DIRECTORY/server.log" ]]; then
    install -d -m 0755 "$(dirname "$DIAGNOSTIC_LOG_FILE")"
    if [[ "$PROFILE" == "oracle" ]]; then
      sanitize_oracle_output <"$TEMP_DIRECTORY/server.log" |
        sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g' \
          >"$DIAGNOSTIC_LOG_FILE"
    else
      sed -E \
        -e "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" \
        -e $'s/\x1B\\[[0-9;]*[[:alpha:]]//g' \
        "$TEMP_DIRECTORY/server.log" >"$DIAGNOSTIC_LOG_FILE"
    fi
  fi

  if [[ "$ORACLE_SMOKE_CREATED" == true && "$PROFILE" == "oracle" ]]; then
    ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
    ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
    ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
      "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
        cleanup-smokes --java-home "$SELECTED_JAVA_HOME" \
        --env "$ENV_FILE" >/dev/null 2>&1 || true
    ORACLE_SMOKE_CREATED=false
  fi

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

handle_signal() {
  exit 130
}
trap handle_signal HUP INT TERM

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
    --java)
      [[ $# -ge 2 &&
         ( "$2" == "7" || "$2" == "8" || "$2" == "17" ) ]] || {
        printf 'FALHA: --java exige 7, 8 ou 17\n' >&2
        exit 2
      }
      JAVA_RELEASE="$2"
      shift 2
      ;;
    --server)
      [[ $# -ge 2 && ( "$2" == "9" || "$2" == "26" ) ]] || {
        printf 'FALHA: --server exige 9 ou 26\n' >&2
        exit 2
      }
      SERVER_RELEASE="$2"
      shift 2
      ;;
    --war)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --war exige um arquivo\n' >&2
        exit 2
      }
      WAR_FILE="$2"
      shift 2
      ;;
    --contract-result)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --contract-result exige um arquivo\n' >&2
        exit 2
      }
      CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    --diagnostic-log)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --diagnostic-log exige um arquivo\n' >&2
        exit 2
      }
      DIAGNOSTIC_LOG_FILE="$2"
      shift 2
      ;;
    --manual)
      MANUAL_MODE=true
      shift
      ;;
    --preserve-oracle-smokes)
      PRESERVE_ORACLE_SMOKES=true
      shift
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

if [[ "$PRESERVE_ORACLE_SMOKES" == true &&
      ( "$PROFILE" != "oracle" || -z "$WAR_FILE" ||
        "$MANUAL_MODE" == true ) ]]; then
  printf 'FALHA: --preserve-oracle-smokes exige perfil oracle, WAR e modo não manual\n' >&2
  exit 2
fi

if [[ "$MANUAL_MODE" == true && -z "$WAR_FILE" ]]; then
  printf 'FALHA: --manual exige --war\n' >&2
  exit 2
fi

if [[ "$SERVER_RELEASE" == "26" &&
      "$JAVA_RELEASE" != "8" &&
      "$JAVA_RELEASE" != "17" ]]; then
  printf 'FALHA: WildFly 26 exige --java 8 ou 17\n' >&2
  exit 2
fi

if [[ -n "$WAR_FILE" ]]; then
  if [[ ! -f "$WAR_FILE" ]]; then
    printf 'FALHA: WAR não encontrado: %s\n' "$WAR_FILE" >&2
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    printf 'FALHA: curl é obrigatório para o smoke web\n' >&2
    exit 1
  fi
  WAR_FILE="$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")"
fi

if [[ "$SERVER_RELEASE" == "26" ]]; then
  WILDFLY_HOME_VARIABLE="WILDFLY26_HOME"
  WILDFLY_ARCHIVE_VARIABLE="WILDFLY26_ARCHIVE"
  WILDFLY_RUNTIME_DIRECTORY="wildfly-26.1.3.Final"
  WILDFLY_EXPECTED_VERSION="26.1.3.Final"
  WILDFLY_MANIFEST="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv"
  WILDFLY_MANIFEST_COMPONENT="wildfly-community"
else
  WILDFLY_HOME_VARIABLE="WILDFLY9_HOME"
  WILDFLY_ARCHIVE_VARIABLE="WILDFLY9_ARCHIVE"
  WILDFLY_RUNTIME_DIRECTORY="wildfly-9.0.2.Final"
  WILDFLY_EXPECTED_VERSION="9.0.2.Final"
  WILDFLY_MANIFEST="$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"
  WILDFLY_MANIFEST_COMPONENT="wildfly"
fi
WILDFLY_HOME_VALUE="$(configuration_value "$WILDFLY_HOME_VARIABLE")"
WILDFLY_ARCHIVE_VALUE="$(configuration_value "$WILDFLY_ARCHIVE_VARIABLE")"
HTTP_PORT_VALUE="$(configuration_value WILDFLY_HTTP_PORT)"
MANAGEMENT_PORT_VALUE="$(configuration_value WILDFLY_MANAGEMENT_PORT)"
HTTP_PORT_VALUE="${HTTP_PORT_VALUE:-8080}"
MANAGEMENT_PORT_VALUE="${MANAGEMENT_PORT_VALUE:-9990}"

if [[ ! -x "$WILDFLY_HOME_VALUE/bin/standalone.sh" ||
      ! -x "$WILDFLY_HOME_VALUE/bin/jboss-cli.sh" ]]; then
  printf 'FALHA: %s não aponta para uma distribuição completa\n' \
    "$WILDFLY_HOME_VARIABLE" >&2
  exit 1
fi
if [[ ! -f "$WILDFLY_ARCHIVE_VALUE" ]]; then
  printf 'FALHA: %s não foi fornecido\n' "$WILDFLY_ARCHIVE_VARIABLE" >&2
  exit 1
fi

expected_wildfly_checksum="$(
  awk -F '\t' -v component="$WILDFLY_MANIFEST_COMPONENT" \
    '$1 == component { print $6 }' "$WILDFLY_MANIFEST"
)"
actual_wildfly_checksum="$(
  sha256sum "$WILDFLY_ARCHIVE_VALUE" | awk '{print $1}'
)"
if [[ "$actual_wildfly_checksum" != "$expected_wildfly_checksum" ]]; then
  printf 'FALHA: checksum do WildFly %s diverge do manifesto\n' \
    "$SERVER_RELEASE" >&2
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

if [[ "$JAVA_RELEASE" == "8" ]]; then
  SELECTED_JAVA_HOME="$(configuration_value JAVA8_HOME)"
  java8_archive="$(configuration_value JAVA8_ARCHIVE)"
  java8_configured_checksum="$(configuration_value JAVA8_ARCHIVE_SHA256)"
  java8_expected_archive="$(phase2_manifest_field archive)"
  java8_expected_checksum="$(phase2_manifest_field sha256)"
  java8_actual_checksum=""
  java8_version_output=""

  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" ||
        ! -f "$java8_archive" ]]; then
    printf 'FALHA: JAVA8_HOME e JAVA8_ARCHIVE são obrigatórios com --java 8\n' >&2
    exit 1
  fi
  java8_actual_checksum="$(sha256sum "$java8_archive" | awk '{print $1}')"
  if [[ "$(basename "$java8_archive")" != "$java8_expected_archive" ]] ||
     [[ "${java8_configured_checksum,,}" != "${java8_expected_checksum,,}" ]] ||
     [[ "$java8_actual_checksum" != "$java8_expected_checksum" ]]; then
    printf 'FALHA: arquivo ou checksum do Java 8 diverge do manifesto CP-2A\n' >&2
    exit 1
  fi
  java8_version_output="$("$SELECTED_JAVA_HOME/bin/java" -version 2>&1)"
  if [[ "$java8_version_output" != *'openjdk version "1.8.0_492"'* ||
        "$java8_version_output" != *"(Temurin)"* ]]; then
    printf 'FALHA: Eclipse Temurin OpenJDK 8u492-b09 não foi detectado\n' >&2
    exit 1
  fi
  if [[ "$SERVER_RELEASE" == "26" ]]; then
    RUNTIME_IDENTIFIER="java8-wildfly26.1.3"
  else
    RUNTIME_IDENTIFIER="java8-wildfly9.0.2"
  fi
elif [[ "$JAVA_RELEASE" == "17" ]]; then
  SELECTED_JAVA_HOME="$(configuration_value JAVA17_HOME)"
  java17_archive="$(configuration_value JAVA17_ARCHIVE)"
  java17_configured_checksum="$(
    configuration_value JAVA17_ARCHIVE_SHA256
  )"
  java17_expected_archive="$(
    awk '$2 ~ /^OpenJDK17U-jdk_/ { print $2; exit }' \
      "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
  )"
  java17_expected_checksum="$(
    awk '$2 ~ /^OpenJDK17U-jdk_/ { print $1; exit }' \
      "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
  )"
  java17_actual_checksum=""
  java17_version_output=""

  if [[ "$SERVER_RELEASE" != "26" ]]; then
    printf 'FALHA: Java 17 é aceito somente com WildFly 26 no CP-3A\n' >&2
    exit 1
  fi
  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" ||
        ! -f "$java17_archive" ||
        -z "$java17_expected_archive" ||
        -z "$java17_expected_checksum" ]]; then
    printf 'FALHA: Java 17 e sua identidade no cache são obrigatórios\n' >&2
    exit 1
  fi
  java17_actual_checksum="$(
    sha256sum "$java17_archive" | awk '{print $1}'
  )"
  if [[ "$(basename "$java17_archive")" != "$java17_expected_archive" ]] ||
     [[ "${java17_configured_checksum,,}" != "${java17_expected_checksum,,}" ]] ||
     [[ "$java17_actual_checksum" != "$java17_expected_checksum" ]]; then
    printf 'FALHA: arquivo ou checksum do Java 17 diverge do cache aprovado\n' >&2
    exit 1
  fi
  java17_version_output="$("$SELECTED_JAVA_HOME/bin/java" -version 2>&1)"
  if [[ "$java17_version_output" != *'openjdk version "17.0.20"'* ||
        "$java17_version_output" != *'Temurin-17.0.20+8'* ]]; then
    printf 'FALHA: Eclipse Temurin OpenJDK 17.0.20+8 não foi detectado\n' >&2
    exit 1
  fi
  RUNTIME_IDENTIFIER="java17-wildfly26.1.3"
elif [[ "$PROFILE" == "ci-h2" ]]; then
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_PORTABLE_HOME)"
else
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_HOME)"
fi

if [[ "$PROFILE" == "ci-h2" ]]; then
  H2_JAR_VALUE="$(configuration_value H2_JAR)"
  if [[ "$JAVA_RELEASE" == "17" ]]; then
    H2_MANIFEST="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/runtime-manifest.tsv"
    H2_EXPECTED_JAR="h2-2.4.240.jar"
    H2_MODULE_DIRECTORY="com/h2database/h2/cp3a/main"
    H2_MODULE_FILE="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/h2/module.xml"
  else
    H2_MANIFEST="$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
    H2_EXPECTED_JAR="h2-1.4.200.jar"
    H2_MODULE_DIRECTORY="com/h2database/h2/cp1d/main"
    H2_MODULE_FILE="$REPOSITORY_ROOT/runtime/legacy/h2/module.xml"
  fi
  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" || ! -f "$H2_JAR_VALUE" ]]; then
    printf 'FALHA: Java selecionado e H2 são obrigatórios para ci-h2\n' >&2
    exit 1
  fi
  expected_driver_checksum="$(
    awk -F '\t' '$1 == "h2" { print $6 }' "$H2_MANIFEST"
  )"
  actual_driver_checksum="$(sha256sum "$H2_JAR_VALUE" | awk '{print $1}')"
  if [[ "$(basename "$H2_JAR_VALUE")" != "$H2_EXPECTED_JAR" ||
        "$actual_driver_checksum" != "$expected_driver_checksum" ]]; then
    printf 'FALHA: arquivo ou checksum do H2 diverge do manifesto do gate\n' >&2
    exit 1
  fi
  if [[ "$JAVA_RELEASE" == "17" ]]; then
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/ci-h2.cli"
  elif [[ "$SERVER_RELEASE" == "26" ]]; then
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/ci-h2.cli"
  else
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/ci-h2.cli"
  fi
else
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
    printf 'FALHA: Java selecionado, ojdbc7 e configuração Oracle são obrigatórios\n' >&2
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
  if [[ "$JAVA_RELEASE" == "17" ]]; then
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/oracle.cli"
  elif [[ "$SERVER_RELEASE" == "26" ]]; then
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/oracle.cli"
  else
    PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/oracle.cli"
  fi
fi

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-datasource.XXXXXXXX")"
RUNTIME_HOME="$TEMP_DIRECTORY/$WILDFLY_RUNTIME_DIRECTORY"
install -d -m 0755 "$RUNTIME_HOME"
cp -a "$WILDFLY_HOME_VALUE/." "$RUNTIME_HOME/"
install -d -m 0755 "$RUNTIME_HOME/standalone/log"

if [[ "$JAVA_RELEASE" == "8" && "$SERVER_RELEASE" == "9" ]]; then
  sed -i -E \
    's/[[:space:]]+-XX:MaxPermSize=[^"[:space:]]+//g' \
    "$RUNTIME_HOME/bin/standalone.conf"
fi

if [[ "$SERVER_RELEASE" == "26" ]]; then
  configuration="$RUNTIME_HOME/standalone/configuration/standalone.xml"
  for required_resource in \
    '<https-listener name="https"' \
    '<key-store name="applicationKS">' \
    '<key-manager name="applicationKM"' \
    '<server-ssl-context name="applicationSSC"'; do
    if ! grep -Fq "$required_resource" "$configuration"; then
      printf 'FALHA: recurso HTTPS padrão não localizado: %s\n' \
        "$required_resource" >&2
      exit 1
    fi
  done
  sed -i \
    -e '/<https-listener name="https"/d' \
    -e '/<key-store name="applicationKS">/,/<\/key-store>/d' \
    -e '/<key-manager name="applicationKM"/,/<\/key-manager>/d' \
    -e '/<server-ssl-context name="applicationSSC"/d' \
    "$configuration"
  if grep -Eq 'https-listener name="https"|applicationKS|applicationKM|applicationSSC' \
      "$configuration"; then
    printf 'FALHA: recursos HTTPS desnecessários não foram removidos\n' >&2
    exit 1
  fi
fi

if [[ "$PROFILE" == "ci-h2" ]]; then
  module_directory="$RUNTIME_HOME/modules/$H2_MODULE_DIRECTORY"
  install -d -m 0755 "$module_directory"
  install -m 0644 "$H2_JAR_VALUE" "$module_directory/$H2_EXPECTED_JAR"
  install -m 0644 "$H2_MODULE_FILE" "$module_directory/module.xml"
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
      -Dmigration.bootstrap.h2=true \
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
  printf 'FALHA: WildFly %s não iniciou no tempo esperado\n' \
    "$SERVER_RELEASE" >&2
  if [[ "$PROFILE" == "ci-h2" && -f "$TEMP_DIRECTORY/server.log" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/server.log" |
      sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
  elif [[ -f "$TEMP_DIRECTORY/server.log" ]]; then
    tail -n 40 "$TEMP_DIRECTORY/server.log" |
      sanitize_oracle_output >&2
  else
    printf 'Log do WildFly indisponível para diagnóstico sanitizado\n' >&2
  fi
  exit 1
fi

if [[ "$JAVA_RELEASE" == "8" ]] &&
   grep -Fq 'ignoring option MaxPermSize' "$TEMP_DIRECTORY/server.log"; then
  printf 'FALHA: opção MaxPermSize removida ainda foi enviada ao Java 8\n' >&2
  exit 1
fi

if [[ "$SERVER_RELEASE" == "26" ]] &&
   grep -Eq 'WFLYELY00023|WFLYELY01084' "$TEMP_DIRECTORY/server.log"; then
  printf 'FALHA: runtime WildFly 26 ainda tentou criar keystore HTTPS\n' >&2
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --file="$PROFILE_FILE" >"$TEMP_DIRECTORY/profile.out" 2>&1; then
  printf 'FALHA: não foi possível aplicar o perfil %s\n' "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/profile.out" |
      sanitize_oracle_output >&2
  else
    tail -n 30 "$TEMP_DIRECTORY/profile.out" |
      sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
  fi
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --commands='/subsystem=datasources/data-source=MigrationDS:test-connection-in-pool' \
    >"$TEMP_DIRECTORY/test.out" 2>&1; then
  printf 'FALHA: teste do datasource %s não concluiu\n' "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/test.out" |
      sanitize_oracle_output >&2
  fi
  exit 1
fi

if ! grep -Fq '"outcome" => "success"' "$TEMP_DIRECTORY/test.out" ||
   ! grep -Eq '"result" => (\[true\]|true)' "$TEMP_DIRECTORY/test.out"; then
  printf 'FALHA: pool MigrationDS não confirmou uma conexão no perfil %s\n' \
    "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/test.out" |
      sanitize_oracle_output >&2
  fi
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

if [[ -n "$WAR_FILE" ]]; then
  if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
      --commands="deploy $WAR_FILE --force" \
      >"$TEMP_DIRECTORY/deploy.out" 2>&1; then
    printf 'FALHA: WAR não pôde ser implantado no perfil %s\n' "$PROFILE" >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 40 "$TEMP_DIRECTORY/deploy.out" |
        sanitize_oracle_output >&2
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 40 "$TEMP_DIRECTORY/deploy.out" >&2
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi

  base_url="http://127.0.0.1:$HTTP_PORT_VALUE/wildfly-migration"
  headers="$TEMP_DIRECTORY/headers.out"
  body="$TEMP_DIRECTORY/body.out"
  cookies="$TEMP_DIRECTORY/cookies.txt"
  application_ready=false
  for unused in $(seq 1 45); do
    if curl --silent --show-error --fail \
        --dump-header "$headers" \
        --output "$body" \
        "$base_url/health" &&
       grep -Fq 'status=UP' "$body"; then
      application_ready=true
      break
    fi
    sleep 1
  done
  if [[ "$application_ready" != true ]]; then
    printf 'FALHA: aplicação não ficou saudável no perfil %s\n' "$PROFILE" >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi
  if ! grep -Eiq '^X-Correlation-ID: [A-Za-z0-9._-]+' "$headers"; then
    printf 'FALHA: resposta não publicou X-Correlation-ID válido\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos" ||
     ! grep -Fq 'data-page="pedidos-lista"' "$body" ||
     ! grep -Fq 'LAB-0001' "$body"; then
    printf 'FALHA: listagem JSP/JSTL não exibiu o seed esperado\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos/novo" ||
     ! grep -Fq 'data-page="pedidos-formulario"' "$body"; then
    printf 'FALHA: formulário de pedido não foi renderizado\n' >&2
    exit 1
  fi

  smoke_number="LAB-SMOKE-$(date +%s)-$SERVER_PID"
  if [[ "$PROFILE" == "oracle" ]]; then
    ORACLE_SMOKE_CREATED=true
  fi
  detail_url=""
  if ! detail_url="$(curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --data-urlencode "numero=$smoke_number" \
      --data-urlencode 'clienteNome=Cliente smoke' \
      --data-urlencode 'descricao=Pedido criado pelo smoke CP-1E' \
      --data-urlencode 'valorTotal=19.75' \
      --output "$body" \
      --write-out '%{url_effective}' \
      "$base_url/pedidos")" ||
     ! grep -Fq 'data-page="pedido-detalhe"' "$body" ||
     ! grep -Fq "$smoke_number" "$body" ||
     ! grep -Fq 'Cliente smoke' "$body"; then
    printf 'FALHA: criação e consulta do pedido não concluíram\n' >&2
    exit 1
  fi

  case "$detail_url" in
    "$base_url"/pedidos/detalhe?id=*)
      smoke_id="${detail_url##*id=}"
      smoke_id="${smoke_id%%&*}"
      ;;
    *)
      printf 'FALHA: redirect do pedido não informou o identificador\n' >&2
      exit 1
      ;;
  esac
  if [[ ! "$smoke_id" =~ ^[1-9][0-9]*$ ]]; then
    printf 'FALHA: identificador criado não é positivo\n' >&2
    exit 1
  fi

  upload_file="$TEMP_DIRECTORY/upload-smoke.txt"
  printf 'conteúdo portátil do upload CP-1F\n' >"$upload_file"
  upload_size="$(wc -c <"$upload_file" | tr -d '[:space:]')"
  upload_sha256="$(sha256sum "$upload_file" | awk '{print $1}')"
  if ! curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --form "arquivo=@$upload_file;filename=../upload-smoke.txt;type=text/plain" \
      --output "$body" \
      "$base_url/anexos/upload?pedidoId=$smoke_id" ||
     ! grep -Fq 'data-upload-status="ok"' "$body" ||
     ! grep -Fq 'data-anexo-nome="upload-smoke.txt"' "$body" ||
     ! grep -Fq '>text/plain</td>' "$body" ||
     ! grep -Fq ">$upload_size</td>" "$body" ||
     ! grep -Fq "$upload_sha256" "$body"; then
    printf 'FALHA: upload e metadados comparáveis não concluíram\n' >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi

  oversized_file="$TEMP_DIRECTORY/upload-oversized.bin"
  dd if=/dev/zero of="$oversized_file" \
    bs=1024 count=512 status=none
  printf 'x' >>"$oversized_file"
  oversized_status=""
  if ! oversized_status="$(curl --silent --show-error \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --form "arquivo=@$oversized_file;filename=oversized.bin;type=application/octet-stream" \
      --output "$body" \
      --write-out '%{http_code}' \
      "$base_url/anexos/upload?pedidoId=$smoke_id")"; then
    printf 'FALHA: cenário negativo do limite de upload não respondeu\n' >&2
    exit 1
  fi
  if [[ "$oversized_status" != "413" ]] ||
     ! grep -Fq 'data-page="erro-controlado"' "$body" ||
     ! grep -Fq 'excede o limite de 512 KiB' "$body"; then
    printf 'FALHA: arquivo acima do limite não foi rejeitado com HTTP 413\n' >&2
    exit 1
  fi

  xml_number="LAB-SMOKE-XML-$(date +%s)-$SERVER_PID"
  xml_correlation="cp1f-xml-$SERVER_PID"
  valid_xml="$TEMP_DIRECTORY/pedido-valido.xml"
  sed "s/XML-0001/$xml_number/" \
    "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
    >"$valid_xml"
  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos/importar-xml" ||
     ! grep -Fq 'data-page="pedidos-importacao-xml"' "$body" ||
     ! grep -Fq 'name="arquivoXml"' "$body"; then
    printf 'FALHA: formulário de seleção do arquivo XML não foi renderizado\n' >&2
    exit 1
  fi
  xml_detail_url=""
  if ! xml_detail_url="$(curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --header "X-Correlation-ID: $xml_correlation" \
      --form "arquivoXml=@$valid_xml;type=application/xml" \
      --output "$body" \
      --write-out '%{url_effective}' \
      "$base_url/pedidos/importar-xml")" ||
     ! grep -Fq 'data-xml-import-status="ok"' "$body" ||
     ! grep -Fq "$xml_number" "$body" ||
     ! grep -Fq 'Cliente XML' "$body" ||
     ! grep -Eq '>349[,.]9(0)?<' "$body"; then
    printf 'FALHA: importação XML válida não criou pedido equivalente\n' >&2
    grep -Fq 'data-xml-import-status="ok"' "$body" ||
      printf 'FALHA: marcador de sucesso XML ausente\n' >&2
    grep -Fq "$xml_number" "$body" ||
      printf 'FALHA: número importado ausente no detalhe\n' >&2
    grep -Fq 'Cliente XML' "$body" ||
      printf 'FALHA: cliente importado ausente no detalhe\n' >&2
    grep -Eq '>349[,.]9(0)?<' "$body" ||
      printf 'FALHA: valor importado ausente no detalhe\n' >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi
  case "$xml_detail_url" in
    "$base_url"/pedidos/detalhe?id=*"&importacao=ok")
      ;;
    *)
      printf 'FALHA: redirect da importação XML não preservou o contrato\n' >&2
      exit 1
      ;;
  esac

  if ! grep -Fq \
      'legacy_validator_order=numero-formato,valor-monetario,status-inicial' \
      "$TEMP_DIRECTORY/server.log" ||
     ! grep -Fq 'legacy_xml_import accepted' \
      "$TEMP_DIRECTORY/server.log" ||
     ! grep -Fq "correlation=$xml_correlation" \
      "$TEMP_DIRECTORY/server.log"; then
    printf 'FALHA: descoberta ou correlação do log legado não foi observada\n' >&2
    exit 1
  fi

  validator_xml="$REPOSITORY_ROOT/contract-tests/fixtures/xml/"
  validator_xml="${validator_xml}pedido-invalido-validador.xml"
  validator_status=""
  if ! validator_status="$(curl --silent --show-error \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --header "X-Correlation-ID: $xml_correlation" \
      --header 'Content-Type: application/xml' \
      --data-binary "@$validator_xml" \
      --output "$body" \
      --write-out '%{http_code}' \
      "$base_url/pedidos/importar-xml")"; then
    printf 'FALHA: cenário de rejeição pelo validador não respondeu\n' >&2
    exit 1
  fi
  if [[ "$validator_status" != "400" ]] ||
     ! grep -Fq 'data-page="erro-controlado"' "$body" ||
     ! grep -Fq 'deve iniciar com status NOVO' "$body" ||
     ! grep -Fq \
        'legacy_xml_import rejected reason=domain_validator' \
        "$TEMP_DIRECTORY/server.log"; then
    printf 'FALHA: regra descoberta não rejeitou o status inicial inválido\n' >&2
    exit 1
  fi

  for hostile_fixture in \
    pedido-invalido-xsd.xml \
    pedido-xxe.xml \
    pedido-entidades-expansivas.xml; do
    xml_status=""
    if ! xml_status="$(curl --silent --show-error \
        --cookie-jar "$cookies" \
        --cookie "$cookies" \
        --header 'Content-Type: application/xml' \
        --data-binary \
          "@$REPOSITORY_ROOT/contract-tests/fixtures/xml/$hostile_fixture" \
        --output "$body" \
        --write-out '%{http_code}' \
        "$base_url/pedidos/importar-xml")"; then
      printf 'FALHA: cenário XML negativo não respondeu: %s\n' \
        "$hostile_fixture" >&2
      exit 1
    fi
    if [[ "$xml_status" != "400" ]] ||
       ! grep -Fq 'data-page="erro-controlado"' "$body"; then
      printf 'FALHA: fixture XML deveria ser rejeitada com HTTP 400: %s\n' \
        "$hostile_fixture" >&2
      exit 1
    fi
  done

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos" ||
     grep -Fq 'XML INVÁLIDO COM ESPAÇOS' "$body" ||
     grep -Fq 'XML-VALIDATOR-0001' "$body" ||
     grep -Fq 'XML-XXE-0001' "$body" ||
     grep -Fq 'XML-ENTITY-0001' "$body"; then
    printf 'FALHA: XML rejeitado deixou persistência parcial\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --data-urlencode 'modoExibicao=COMPACTO' \
      --output "$body" \
      "$base_url/preferencia" ||
     ! grep -Fq 'data-display-mode="COMPACTO"' "$body"; then
    printf 'FALHA: preferência não persistiu na HttpSession\n' >&2
    exit 1
  fi

  contract_result="$CONTRACT_RESULT_FILE"
  if [[ -z "$contract_result" ]]; then
    contract_result="$TEMP_DIRECTORY/contract-result-$PROFILE.json"
  fi
  contract_correlation="cp1f-contract-$SERVER_PID"
  commit_sha="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
  source_commit_sha="${MIGRATION_SOURCE_COMMIT:-$commit_sha}"
  if ! "$REPOSITORY_ROOT/contract-tests/run.sh" \
      --base-url "$base_url" \
      --profile "$PROFILE" \
      --war "$WAR_FILE" \
      --result "$contract_result" \
      --commit "$commit_sha" \
      --source-commit "$source_commit_sha" \
      --runtime "$RUNTIME_IDENTIFIER" \
      --correlation-id "$contract_correlation"; then
    printf 'FALHA: suíte externa de contratos falhou no perfil %s\n' \
      "$PROFILE" >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi
  if ! grep -Fq \
      'legacy_validator_order=numero-formato,valor-monetario,status-inicial' \
      "$TEMP_DIRECTORY/server.log" ||
     ! grep -Fq \
      'legacy_xml_import rejected reason=domain_validator' \
      "$TEMP_DIRECTORY/server.log" ||
     ! grep -Fq "correlation=$contract_correlation" \
      "$TEMP_DIRECTORY/server.log"; then
    printf 'FALHA: logs da execução externa não preservaram o contrato\n' >&2
    exit 1
  fi

  if [[ "$SERVER_RELEASE" == "26" ]] &&
     grep -Eq \
       'ClassNotFoundException|NoClassDefFoundError|(^|[^A-Za-z])LinkageError' \
       "$TEMP_DIRECTORY/server.log"; then
    printf 'FALHA: WildFly 26 registrou quebra de classloader\n' >&2
    exit 1
  fi

  if [[ "$PROFILE" == "oracle" ]]; then
    if [[ "$PRESERVE_ORACLE_SMOKES" == true ]]; then
      ORACLE_SMOKE_CREATED=false
      printf 'OK: dados LAB-SMOKE-* preservados temporariamente para comparação\n'
    else
      if ! ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
          ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
          ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
          "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
            cleanup-smokes --java-home "$SELECTED_JAVA_HOME" \
            --env "$ENV_FILE" \
            >"$TEMP_DIRECTORY/cleanup.out" 2>&1; then
        printf 'FALHA: dados transitórios do smoke Oracle não foram limpos\n' >&2
        exit 1
      fi
      ORACLE_SMOKE_CREATED=false
    fi
  fi

  printf 'OK: fluxo web %s validou pedidos, sessão, upload e importação XML\n' \
    "$PROFILE"
fi

printf 'OK: datasource %s publicou java:/jdbc/MigrationDS e passou no pool em loopback\n' \
  "$PROFILE"

if [[ "$MANUAL_MODE" == true ]]; then
  printf '%s\n' "$SERVER_PID" >"$TEMP_DIRECTORY/manual-server.pid"
  printf '\nAplicação legada disponível somente em loopback:\n'
  printf '  Lista:  http://127.0.0.1:%s/wildfly-migration/pedidos\n' \
    "$HTTP_PORT_VALUE"
  printf '  Novo:   http://127.0.0.1:%s/wildfly-migration/pedidos/novo\n' \
    "$HTTP_PORT_VALUE"
  printf '  Saúde:  http://127.0.0.1:%s/wildfly-migration/health\n' \
    "$HTTP_PORT_VALUE"
  printf '\nLog bruto do WildFly:\n'
  printf '  Arquivo: %s\n' "$TEMP_DIRECTORY/server.log"
  printf '  Acompanhar: tail -f -- %q\n' "$TEMP_DIRECTORY/server.log"
  if [[ "$PROFILE" == "oracle" ]]; then
    printf '  ATENÇÃO: revise host, serviço, usuário e URL interna antes de compartilhar este log.\n'
  fi
  printf 'Use outro terminal ou navegador para os testes. Ctrl+C encerra e limpa o runtime temporário.\n'

  while kill -0 "$SERVER_PID" >/dev/null 2>&1; do
    sleep 5
  done
  printf 'FALHA: WildFly encerrou durante a sessão manual\n' >&2
  exit 1
fi
