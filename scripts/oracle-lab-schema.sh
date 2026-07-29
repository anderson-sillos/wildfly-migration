#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
ACTION=""
JAVA_HOME_ARGUMENT=""
JAVA_RELEASE="7"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-oracle.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/oracle-lab-schema.sh inspect [--java 7|8] [--java-home DIRETORIO] [--env ARQUIVO]
  ./scripts/oracle-lab-schema.sh apply [--java 7|8] [--java-home DIRETORIO] [--env ARQUIVO]
  ./scripts/oracle-lab-schema.sh verify [--java 7|8] [--java-home DIRETORIO] [--env ARQUIVO]
  ./scripts/oracle-lab-schema.sh cleanup-smokes [--java 7|8] [--java-home DIRETORIO] [--env ARQUIVO]

inspect é somente leitura. apply executa 001_schema.sql e 002_seed.sql apenas
depois de aprovar identidade, container, quota, privilégios e objetos existentes.
cleanup-smokes remove somente pedidos cujo número começa por LAB-SMOKE-.
Nenhuma ação remove o schema ou executa rollback.sql.
USAGE
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-oracle.*)
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

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi
ACTION="$1"
shift
case "$ACTION" in
  inspect|apply|verify|cleanup-smokes)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    printf 'FALHA: ação inválida\n' >&2
    usage >&2
    exit 2
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --env exige um arquivo\n' >&2
        exit 2
      }
      ENV_FILE="$2"
      shift 2
      ;;
    --java-home)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --java-home exige um diretório\n' >&2
        exit 2
      }
      JAVA_HOME_ARGUMENT="$2"
      shift 2
      ;;
    --java)
      [[ $# -ge 2 && ( "$2" == "7" || "$2" == "8" ) ]] || {
        printf 'FALHA: --java exige 7 ou 8\n' >&2
        exit 2
      }
      JAVA_RELEASE="$2"
      shift 2
      ;;
    *)
      printf 'FALHA: argumento desconhecido\n' >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$JAVA_RELEASE" == "8" ]]; then
  CONFIGURED_JAVA_HOME="$(configuration_value JAVA8_HOME)"
else
  CONFIGURED_JAVA_HOME="$(configuration_value JAVA7_HOME)"
fi
SELECTED_JAVA_HOME="${JAVA_HOME_ARGUMENT:-$CONFIGURED_JAVA_HOME}"
OJDBC7_JAR_VALUE="$(configuration_value OJDBC7_JAR)"
OJDBC7_SHA256_VALUE="$(configuration_value OJDBC7_SHA256)"
export ORACLE_DB_URL="$(configuration_value ORACLE_DB_URL)"
export ORACLE_DB_USER="$(configuration_value ORACLE_DB_USER)"
export ORACLE_DB_PASSWORD="$(configuration_value ORACLE_DB_PASSWORD)"

if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" ||
      ! -x "$SELECTED_JAVA_HOME/bin/javac" ||
      ! -f "$OJDBC7_JAR_VALUE" ||
      -z "$ORACLE_DB_URL" ||
      -z "$ORACLE_DB_USER" ||
      -z "$ORACLE_DB_PASSWORD" ]]; then
  printf 'FALHA: JDK selecionado, ojdbc7 e configuração Oracle são obrigatórios\n' >&2
  exit 1
fi

actual_checksum="$(sha256sum "$OJDBC7_JAR_VALUE" | awk '{print $1}')"
if [[ ! "$OJDBC7_SHA256_VALUE" =~ ^[[:xdigit:]]{64}$ ]] ||
   [[ "$actual_checksum" != "${OJDBC7_SHA256_VALUE,,}" ]]; then
  printf 'FALHA: checksum do ojdbc7 não foi aprovado\n' >&2
  exit 1
fi

"$SELECTED_JAVA_HOME/bin/javac" \
  -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY" \
  "$REPOSITORY_ROOT/scripts/OracleLabSchema.java"

"$SELECTED_JAVA_HOME/bin/java" \
  -cp "$TEMP_DIRECTORY:$OJDBC7_JAR_VALUE" \
  OracleLabSchema "$ACTION" "$REPOSITORY_ROOT"
