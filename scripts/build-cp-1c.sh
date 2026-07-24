#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"

usage() {
  printf 'Uso: ./scripts/build-cp-1c.sh [--env ARQUIVO]\n'
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

  if (( count != 1 )); then
    return 1
  fi
  printf '%s' "$result"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      if [[ $# -lt 2 ]]; then
        printf 'FALHA: --env exige um arquivo\n' >&2
        exit 2
      fi
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

if [[ ! -f "$ENV_FILE" ]]; then
  printf 'FALHA: arquivo de ambiente não encontrado: %s\n' "$ENV_FILE" >&2
  exit 1
fi

JAVA7_HOME="$(read_env_value JAVA7_HOME "$ENV_FILE" || true)"
MAVEN_HOME="$(read_env_value MAVEN_HOME "$ENV_FILE" || true)"
JAVA7_TRUSTSTORE="$(read_env_value JAVA7_TRUSTSTORE "$ENV_FILE" || true)"

if [[ ! -x "$JAVA7_HOME/bin/java" ||
      ! -x "$JAVA7_HOME/bin/jar" ||
      ! -x "$JAVA7_HOME/bin/javap" ]]; then
  printf 'FALHA: JAVA7_HOME não aponta para um JDK completo\n' >&2
  exit 1
fi
if [[ ! -x "$MAVEN_HOME/bin/mvn" ]]; then
  printf 'FALHA: MAVEN_HOME não aponta para o Maven 3.8.9\n' >&2
  exit 1
fi
if [[ ! -f "$JAVA7_TRUSTSTORE" ]]; then
  printf 'FALHA: JAVA7_TRUSTSTORE não aponta para um truststore JKS atualizado\n' >&2
  exit 1
fi

maven_version="$(
  JAVA_HOME="$JAVA7_HOME" PATH="$JAVA7_HOME/bin:$PATH" \
    "$MAVEN_HOME/bin/mvn" --version 2>&1
)"
if [[ "$maven_version" != *"Apache Maven 3.8.9"* ||
      "$maven_version" != *"Java version: 1.7.0_80"* ]]; then
  printf 'FALHA: o build exige Maven 3.8.9 executando com Java 7u80\n' >&2
  exit 1
fi

JAVA_HOME="$JAVA7_HOME" \
PATH="$JAVA7_HOME/bin:$PATH" \
MAVEN_OPTS="-Dhttps.protocols=TLSv1.2 -Djavax.net.ssl.trustStore=$JAVA7_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit" \
  "$MAVEN_HOME/bin/mvn" -B -ntp -f "$REPOSITORY_ROOT/app/pom.xml" \
  -U clean verify \
  org.apache.maven.plugins:maven-dependency-plugin:3.1.2:tree \
  -DoutputFile=target/dependency-tree.txt

"$REPOSITORY_ROOT/scripts/audit-legacy-war.sh" \
  --java-home "$JAVA7_HOME" \
  "$REPOSITORY_ROOT/app/target/wildfly-migration.war"
