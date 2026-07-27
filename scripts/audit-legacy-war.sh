#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
JAVA_HOME_ARGUMENT=""
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-war-audit.XXXXXXXX")"

usage() {
  printf 'Uso: ./scripts/audit-legacy-war.sh --java-home DIRETORIO [WAR]\n'
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-war-audit.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada: %s\n' \
        "$TEMP_DIRECTORY" >&2
      ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --java-home)
      if [[ $# -lt 2 ]]; then
        printf 'FALHA: --java-home exige um diretório\n' >&2
        exit 2
      fi
      JAVA_HOME_ARGUMENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'FALHA: opção desconhecida: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      WAR_FILE="$1"
      shift
      if [[ $# -ne 0 ]]; then
        printf 'FALHA: somente um WAR pode ser informado\n' >&2
        exit 2
      fi
      ;;
  esac
done

if [[ -z "$JAVA_HOME_ARGUMENT" ||
      ! -x "$JAVA_HOME_ARGUMENT/bin/jar" ||
      ! -x "$JAVA_HOME_ARGUMENT/bin/javap" ]]; then
  printf 'FALHA: Java informado não contém bin/jar e bin/javap\n' >&2
  exit 1
fi

if [[ ! -f "$WAR_FILE" ]]; then
  printf 'FALHA: WAR não encontrado: %s\n' "$WAR_FILE" >&2
  exit 1
fi
WAR_FILE="$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")"

if [[ ! -f "$EXPECTED_LIBRARIES" ]]; then
  printf 'FALHA: allowlist de WEB-INF/lib ausente\n' >&2
  exit 1
fi

"$JAVA_HOME_ARGUMENT/bin/jar" tf "$WAR_FILE" > "$TEMP_DIRECTORY/entries.txt"

awk '
  /^WEB-INF\/lib\/[^/]+\.jar$/ {
    sub(/^WEB-INF\/lib\//, "")
    print
  }
' "$TEMP_DIRECTORY/entries.txt" |
  LC_ALL=C sort > "$TEMP_DIRECTORY/actual-libraries.txt"

LC_ALL=C sort "$EXPECTED_LIBRARIES" > "$TEMP_DIRECTORY/expected-libraries.txt"

if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt"; then
  printf 'FALHA: WEB-INF/lib diverge da allowlist aprovada\n' >&2
  exit 1
fi

if grep -Eq \
    '^WEB-INF/lib/(servlet-api|jsp-api|jstl-api|h2)-[^/]+\.jar$|^WEB-INF/lib/ojdbc[^/]*\.jar$' \
    "$TEMP_DIRECTORY/entries.txt"; then
  printf 'FALHA: API do contêiner ou driver de banco foi empacotado\n' >&2
  exit 1
fi

if grep -Eiq \
    '(^|/)(\.env($|\.)|[^/]+\.(pem|key|p12|pfx|jks|wallet)$|tnsnames\.ora$|sqlnet\.ora$|ojdbc\.properties$)' \
    "$TEMP_DIRECTORY/entries.txt"; then
  printf 'FALHA: arquivo de segredo ou configuração sensível foi empacotado\n' >&2
  exit 1
fi

for required_entry in \
  "WEB-INF/web.xml" \
  "WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class"; do
  if ! grep -Fxq "$required_entry" "$TEMP_DIRECTORY/entries.txt"; then
    printf 'FALHA: entrada obrigatória ausente no WAR: %s\n' \
      "$required_entry" >&2
    exit 1
  fi
done

(
  cd "$TEMP_DIRECTORY"
  "$JAVA_HOME_ARGUMENT/bin/jar" xf "$WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class
)

if ! "$JAVA_HOME_ARGUMENT/bin/javap" -verbose \
    -classpath "$TEMP_DIRECTORY/WEB-INF/classes" \
    br.com.asillos.migration.LegacyBuildMarker |
    grep -Fq 'major version: 51'; then
  printf 'FALHA: bytecode do marcador não é Java 7 (major 51)\n' >&2
  exit 1
fi

if git -C "$REPOSITORY_ROOT" ls-files '*.jar' | grep -q .; then
  printf 'FALHA: há JAR versionado no repositório\n' >&2
  exit 1
fi

tracked_sensitive="$(
  git -C "$REPOSITORY_ROOT" ls-files | awk '
    /(^|\/)\.env($|\.)/ && $0 !~ /(^|\/)\.env\.example$/ ||
    /(^|\/)\.secrets\// ||
    /(^|\/)oracle-wallet\// ||
    /\.(pem|key|p12|pfx|jks|wallet)$/ ||
    /(^|\/)(tnsnames|sqlnet)\.ora$/ { print; exit }
  '
)"
if [[ -n "$tracked_sensitive" ]]; then
  printf 'FALHA: há segredo ou configuração sensível versionada\n' >&2
  exit 1
fi

manual_jar="$(
  find "$REPOSITORY_ROOT/app" \
    -path "$REPOSITORY_ROOT/app/target" -prune -o \
    -type f -name '*.jar' -print -quit
)"
if [[ -n "$manual_jar" ]]; then
  printf 'FALHA: JAR manual encontrado fora de app/target\n' >&2
  exit 1
fi

war_checksum="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
library_count="$(wc -l < "$TEMP_DIRECTORY/actual-libraries.txt" | tr -d ' ')"

printf 'OK: WAR legado auditado — %s bibliotecas, bytecode Java 7, SHA-256 %s\n' \
  "$library_count" "$war_checksum"
