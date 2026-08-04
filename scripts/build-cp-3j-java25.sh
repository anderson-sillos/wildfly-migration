#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
RESULT_FILE="$ROOT/migration/evidence/CP-3J/java25-build.json"
OUTPUT_FILE="$ROOT/migration/evidence/CP-3J/java25-build.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --result) RESULT_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    -h|--help)
      printf '%s\n' 'Uso: ./scripts/build-cp-3j-java25.sh [--env ARQUIVO] [--result ARQUIVO] [--output ARQUIVO]'
      exit 0
      ;;
    *) printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2; exit 2 ;;
  esac
done

value() {
  local key="$1"
  local exported="${!key:-}"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    grep -E "^$key=" "$ENV_FILE" | head -1 | cut -d= -f2- |
      sed -e 's/^"//' -e 's/"$//'
  fi
}

JAVA_HOME_VALUE="$(value JAVA25_HOME)"
MAVEN_HOME_VALUE="$(value MAVEN_HOME)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$MAVEN_HOME_VALUE/bin/mvn" ]] || {
  printf 'FALHA: JAVA25_HOME e MAVEN_HOME devem apontar para ferramentas completas\n' >&2
  exit 1
}

TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3j-build.XXXXXXXX)"
cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3j-build.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2 ;;
  esac
}
trap cleanup EXIT

BUILD_DIRECTORY="$ROOT/app/target/cp3j-java25"
set +e
JAVA_HOME="$JAVA_HOME_VALUE" \
PATH="$JAVA_HOME_VALUE/bin:$PATH" \
MAVEN_OPTS='-Dhttps.protocols=TLSv1.2' \
  "$MAVEN_HOME_VALUE/bin/mvn" -B -ntp \
  -f "$ROOT/app/pom.xml" \
  -Pci-h2,cp-3e-jakarta11 \
  -Djava.version.range='[25,26)' \
  -Dmigration.build.directory="$BUILD_DIRECTORY" \
  clean verify >"$TEMP_DIRECTORY/build.out" 2>&1
BUILD_STATUS="$?"
set -e

install -d -m 0755 "$(dirname "$OUTPUT_FILE")" "$(dirname "$RESULT_FILE")"
sed -E \
  -e "s#$ROOT#<repository>#g" \
  -e 's#/opt/migration-lab/tools/[^[:space:]]+#<runtime-tool>#g' \
  -e $'s/\x1B\\[[0-9;]*[[:alpha:]]//g' \
  -e 's/[[:space:]]+$//' \
  "$TEMP_DIRECTORY/build.out" >"$OUTPUT_FILE"

if [[ "$BUILD_STATUS" -eq 0 ]]; then
  BUILD_OUTCOME=passed
else
  BUILD_OUTCOME=failed
fi
COMPILATION_ERRORS="$(grep -c 'COMPILATION ERROR' "$OUTPUT_FILE" || true)"
WAR_FILE="$BUILD_DIRECTORY/wildfly-migration.war"
WAR_SHA256=""
if [[ -f "$WAR_FILE" ]]; then
  WAR_SHA256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
fi
cat >"$RESULT_FILE" <<EOF
{
  "schema": "wildfly-migration-cp3j-java25-build/v1",
  "checkpoint": "CP-3J",
  "activity": "3.47",
  "profile": "cp-3e-jakarta11",
  "javaVersionRangeOverride": "[25,26)",
  "runtime": "Temurin 25.0.4+7/Maven 3.9.16",
  "server": "WildFly Community 41.0.0.Final",
  "api": "jakarta.platform:jakarta.jakartaee-web-api:11.0.0",
  "bytecodeTarget": "21",
  "buildDirectory": "app/target/cp3j-java25",
  "buildOutcome": "$BUILD_OUTCOME",
  "exitCode": $BUILD_STATUS,
  "compilationErrorBlocks": $COMPILATION_ERRORS,
  "warSha256": "$WAR_SHA256"
}
EOF

if [[ "$BUILD_STATUS" -ne 0 ]]; then
  printf 'FALHA CP-3J/3.47: build Java 25 não passou; saída em %s\n' "$OUTPUT_FILE" >&2
  exit "$BUILD_STATUS"
fi

printf 'OK: build CP-3J/3.47 com OpenJDK 25 concluído; WAR em %s\n' "$WAR_FILE"
