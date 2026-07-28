#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1f-upload.XXXXXXXX"
)"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1f-upload.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

required_paths=(
  "app/src/main/java/br/com/asillos/migration/persistence/AnexoRepository.java"
  "app/src/main/java/br/com/asillos/migration/web/UploadServlet.java"
  "app/src/main/resources/mybatis/AnexoMapper.xml"
  "app/src/main/webapp/WEB-INF/views/pedidos/detalhe-content.jsp"
  "app/src/main/webapp/WEB-INF/web.xml"
  "docs/legacy-upload.md"
  "scripts/ValidateLegacyUpload.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: recurso de upload ausente: %s\n' "$path" >&2
    exit 1
  fi
done

install -d -m 0755 "$TEMP_DIRECTORY/classes"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyUpload.java"
java -cp "$TEMP_DIRECTORY/classes" \
  ValidateLegacyUpload "$REPOSITORY_ROOT"

if grep -REiq \
    'jdbc:(oracle|h2):|ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=' \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/web/UploadServlet.java" \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/persistence/AnexoRepository.java" \
    "$REPOSITORY_ROOT/docs/legacy-upload.md"; then
  printf 'FALHA: endpoint ou credencial foi incluído no fluxo de upload\n' >&2
  exit 1
fi

printf 'OK: upload legado validado sem endpoint ou segredo embutido\n'
