#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
PROFILE=""

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/build-cp-1d.sh --profile ci-h2|oracle [--env ARQUIVO]

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
  ci-h2)
    JAVA_HOME_VALUE="$(configuration_value JAVA7_PORTABLE_HOME)"
    EXPECTED_JAVA='Java version: 1.7.0_352'
    MAVEN_PROFILE='ci-h2'
    MAVEN_OPTIONS='-Dhttps.protocols=TLSv1.2'
    ;;
  oracle)
    JAVA_HOME_VALUE="$(configuration_value JAVA7_HOME)"
    JAVA7_TRUSTSTORE_VALUE="$(configuration_value JAVA7_TRUSTSTORE)"
    EXPECTED_JAVA='Java version: 1.7.0_80'
    MAVEN_PROFILE='oracle'
    if [[ ! -f "$JAVA7_TRUSTSTORE_VALUE" ]]; then
      printf 'FALHA: JAVA7_TRUSTSTORE não aponta para um JKS atualizado\n' >&2
      exit 1
    fi
    MAVEN_OPTIONS="-Dhttps.protocols=TLSv1.2 -Djavax.net.ssl.trustStore=$JAVA7_TRUSTSTORE_VALUE -Djavax.net.ssl.trustStorePassword=changeit"
    ;;
  *)
    printf 'FALHA: informe --profile ci-h2 ou --profile oracle\n' >&2
    exit 2
    ;;
esac

MAVEN_HOME_VALUE="$(configuration_value MAVEN_HOME)"

if [[ ! -x "$JAVA_HOME_VALUE/bin/java" ||
      ! -x "$JAVA_HOME_VALUE/bin/jar" ||
      ! -x "$JAVA_HOME_VALUE/bin/javap" ]]; then
  printf 'FALHA: o Java selecionado não aponta para um JDK completo\n' >&2
  exit 1
fi
if [[ ! -x "$MAVEN_HOME_VALUE/bin/mvn" ]]; then
  printf 'FALHA: MAVEN_HOME não aponta para o Maven 3.8.9\n' >&2
  exit 1
fi

maven_version="$(
  JAVA_HOME="$JAVA_HOME_VALUE" PATH="$JAVA_HOME_VALUE/bin:$PATH" \
    "$MAVEN_HOME_VALUE/bin/mvn" --version 2>&1
)"
if [[ "$maven_version" != *"Apache Maven 3.8.9"* ||
      "$maven_version" != *"$EXPECTED_JAVA"* ]]; then
  printf 'FALHA: Maven 3.8.9 não está executando com o Java do perfil %s\n' \
    "$PROFILE" >&2
  exit 1
fi

JAVA_HOME="$JAVA_HOME_VALUE" \
PATH="$JAVA_HOME_VALUE/bin:$PATH" \
MAVEN_OPTS="$MAVEN_OPTIONS" \
  "$MAVEN_HOME_VALUE/bin/mvn" -B -ntp \
  -f "$REPOSITORY_ROOT/app/pom.xml" \
  -P"$MAVEN_PROFILE" \
  clean verify \
  org.apache.maven.plugins:maven-dependency-plugin:3.1.2:tree \
  -DoutputFile=target/dependency-tree.txt

"$REPOSITORY_ROOT/scripts/audit-legacy-war.sh" \
  --java-home "$JAVA_HOME_VALUE" \
  "$REPOSITORY_ROOT/app/target/wildfly-migration.war"

printf 'OK: WAR do CP-1D construído e auditado no perfil %s\n' "$PROFILE"
