#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
RESULT_FILE="$ROOT/migration/evidence/CP-3F/jakarta-build.json"
OUTPUT_FILE="$ROOT/migration/evidence/CP-3F/jakarta-build.txt"
IDE_REBUILD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --result) RESULT_FILE="$2"; shift 2 ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    --ide-rebuild) IDE_REBUILD=true; shift ;;
    -h|--help)
      printf '%s\n' 'Uso: ./scripts/build-cp-3f-jakarta.sh [--env ARQUIVO] [--result ARQUIVO] [--output ARQUIVO] [--ide-rebuild]'
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

JAVA_HOME_VALUE="$(value JAVA21_HOME)"
MAVEN_HOME_VALUE="$(value MAVEN_HOME)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$MAVEN_HOME_VALUE/bin/mvn" ]] || {
  printf 'FALHA: JAVA21_HOME e MAVEN_HOME devem apontar para ferramentas completas\n' >&2
  exit 1
}

TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3f-build.XXXXXXXX)"
cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3f-build.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2 ;;
  esac
}
trap cleanup EXIT

if [[ "$IDE_REBUILD" == "true" ]]; then
  # O JDT importa o POM no diretório Maven padrão e espera os tipos gerados
  # em app/target/generated-sources. O CI continua isolado em cp3f-jakarta11.
  BUILD_DIRECTORY="$ROOT/app/target"
else
  BUILD_DIRECTORY="$ROOT/app/target/cp3f-jakarta11"
fi
set +e
JAVA_HOME="$JAVA_HOME_VALUE" \
PATH="$JAVA_HOME_VALUE/bin:$PATH" \
MAVEN_OPTS='-Dhttps.protocols=TLSv1.2' \
  "$MAVEN_HOME_VALUE/bin/mvn" -B -ntp \
  -f "$ROOT/app/pom.xml" \
  -Pci-h2,cp-3e-jakarta11 \
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
cat >"$RESULT_FILE" <<EOF
{
  "schema": "wildfly-migration-cp3f-jakarta-build/v1",
  "checkpoint": "CP-3F",
  "profile": "cp-3e-jakarta11",
  "runtime": "Temurin 21.0.12+8/Maven 3.9.16",
  "api": "jakarta.platform:jakarta.jakartaee-web-api:11.0.0",
  "buildOutcome": "$BUILD_OUTCOME",
  "exitCode": $BUILD_STATUS,
  "compilationErrorBlocks": $COMPILATION_ERRORS
}
EOF

if [[ "$BUILD_STATUS" -ne 0 ]]; then
  printf 'FALHA CP-3F: build Jakarta não passou; saída em %s\n' "$OUTPUT_FILE" >&2
  exit "$BUILD_STATUS"
fi

printf 'OK: build Jakarta CP-3F concluído; saída em %s\n' "$OUTPUT_FILE"
