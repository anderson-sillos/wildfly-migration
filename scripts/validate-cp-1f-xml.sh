#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1f-xml.XXXXXXXX"
)"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1f-xml.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

required_paths=(
  "app/src/main/java/br/com/asillos/migration/integration/xml/LegacyPedidoXmlParser.java"
  "app/src/main/java/br/com/asillos/migration/integration/xml/XmlImportException.java"
  "app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java"
  "app/src/main/resources/xsd/pedido-importacao-v1.xsd"
  "app/src/main/webapp/WEB-INF/views/pedidos/importacao-xml.jsp"
  "app/src/main/webapp/WEB-INF/views/pedidos/importacao-xml-content.jsp"
  "contract-tests/fixtures/xml/pedido-valido.xml"
  "contract-tests/fixtures/xml/pedido-invalido-xsd.xml"
  "contract-tests/fixtures/xml/pedido-invalido-validador.xml"
  "contract-tests/fixtures/xml/pedido-xxe.xml"
  "contract-tests/fixtures/xml/pedido-entidades-expansivas.xml"
  "docs/legacy-xml-import.md"
  "scripts/ValidateLegacyXmlImport.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: recurso da importação XML ausente: %s\n' "$path" >&2
    exit 1
  fi
done

install -d -m 0755 "$TEMP_DIRECTORY/classes"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyXmlImport.java"
java -cp "$TEMP_DIRECTORY/classes" \
  ValidateLegacyXmlImport "$REPOSITORY_ROOT"

if grep -REiq \
    'jdbc:(oracle|h2):|ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=' \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/integration/xml" \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java" \
    "$REPOSITORY_ROOT/docs/legacy-xml-import.md"; then
  printf 'FALHA: endpoint ou credencial foi incluído no fluxo XML\n' >&2
  exit 1
fi

printf 'OK: importação XML validada sem endpoint externo ou segredo embutido\n'
