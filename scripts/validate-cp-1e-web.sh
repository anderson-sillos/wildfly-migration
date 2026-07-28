#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1e-web.XXXXXXXX")"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1e-web.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

install -d -m 0755 "$TEMP_DIRECTORY/classes"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyWeb.java"
java -cp "$TEMP_DIRECTORY/classes" \
  ValidateLegacyWeb "$REPOSITORY_ROOT"

if find "$REPOSITORY_ROOT/app/src/main/webapp" \
    -path "$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF" -prune -o \
    -type f -name '*.jsp' -print -quit | grep -q .; then
  printf 'FALHA: JSP acessível diretamente fora de WEB-INF\n' >&2
  exit 1
fi

if grep -REiq \
    'jdbc:(oracle|h2):|ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=' \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/web" \
    "$REPOSITORY_ROOT/app/src/main/webapp"; then
  printf 'FALHA: endpoint ou credencial foi incluído na camada web\n' >&2
  exit 1
fi

printf 'OK: camada web CP-1E validada sem endpoint ou segredo embutido\n'
