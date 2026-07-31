#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
JAVA_HOME_ARGUMENT=""
EXPECTED_BYTECODE_MAJOR="51"
EXPECTED_JAVA_LABEL="Java 7"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-war-audit.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/audit-legacy-war.sh --java-home DIRETORIO \
    [--expected-libraries ARQUIVO] \
    [--expected-bytecode 51|52|61] [--expected-java-label TEXTO] [WAR]
USAGE
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
    --expected-libraries)
      if [[ $# -lt 2 || -z "$2" ]]; then
        printf 'FALHA: --expected-libraries exige um arquivo\n' >&2
        exit 2
      fi
      EXPECTED_LIBRARIES="$2"
      shift 2
      ;;
    --expected-bytecode)
      if [[ $# -lt 2 ||
            ( "$2" != "51" && "$2" != "52" && "$2" != "61" ) ]]; then
        printf 'FALHA: --expected-bytecode exige 51, 52 ou 61\n' >&2
        exit 2
      fi
      EXPECTED_BYTECODE_MAJOR="$2"
      shift 2
      ;;
    --expected-java-label)
      if [[ $# -lt 2 || -z "$2" ]]; then
        printf 'FALHA: --expected-java-label exige um texto\n' >&2
        exit 2
      fi
      EXPECTED_JAVA_LABEL="$2"
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

if grep -Eq \
    '^WEB-INF/lib/(servlet-api|javax\.servlet-api|jakarta\.servlet-api|jsp-api|javax\.servlet\.jsp-api|jakarta\.servlet\.jsp-api|jstl-api|javax\.servlet\.jsp\.jstl-api|jakarta\.servlet\.jsp\.jstl-api|javax\.el-api|jakarta\.el-api|javaee-api|javaee-web-api|jakarta\.jakartaee-api|jakarta\.jakartaee-web-api|h2)-[^/]+\.jar$|^WEB-INF/lib/ojdbc[^/]*\.jar$' \
    "$TEMP_DIRECTORY/entries.txt"; then
  printf 'FALHA: API do contêiner ou driver de banco foi empacotado\n' >&2
  exit 1
fi

if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt"; then
  printf 'FALHA: WEB-INF/lib diverge da allowlist aprovada\n' >&2
  exit 1
fi

mkdir -p "$TEMP_DIRECTORY/embedded"
(
  cd "$TEMP_DIRECTORY/embedded"
  "$JAVA_HOME_ARGUMENT/bin/jar" xf "$WAR_FILE" WEB-INF/lib
)

while IFS= read -r library; do
  "$JAVA_HOME_ARGUMENT/bin/jar" tf \
    "$TEMP_DIRECTORY/embedded/WEB-INF/lib/$library" \
    >"$TEMP_DIRECTORY/embedded-entries.txt"
  if grep -Eq \
      '^(javax|jakarta)/servlet/Servlet\.class$|^(javax|jakarta)/servlet/jsp/JspPage\.class$|^(javax|jakarta)/servlet/jsp/jstl/core/Config\.class$|^(javax|jakarta)/el/ELContext\.class$' \
      "$TEMP_DIRECTORY/embedded-entries.txt"; then
    printf 'FALHA: biblioteca empacota classes de API do contêiner: %s\n' \
      "$library" >&2
    exit 1
  fi
done <"$TEMP_DIRECTORY/actual-libraries.txt"

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
    grep -Fq "major version: $EXPECTED_BYTECODE_MAJOR"; then
  printf 'FALHA: bytecode do marcador não é %s (major %s)\n' \
    "$EXPECTED_JAVA_LABEL" "$EXPECTED_BYTECODE_MAJOR" >&2
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

printf 'OK: WAR auditado — %s bibliotecas, bytecode %s (major %s), SHA-256 %s\n' \
  "$library_count" "$EXPECTED_JAVA_LABEL" "$EXPECTED_BYTECODE_MAJOR" \
  "$war_checksum"
