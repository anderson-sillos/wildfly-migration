#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POM="$REPOSITORY_ROOT/app/pom.xml"
ALLOWLIST="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt"
TLD="$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/migration.tld"
WEB_XML="$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/web.xml"
TILES_DEFS="$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/tiles-defs.xml"
BASE_LAYOUT="$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/layout/base.jsp"
HANDLER="$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/web/tag/StatusPedidoTag.java"
TASKS="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
DECISION="$REPOSITORY_ROOT/docs/cp-3d-java17-gate.md"
STEP="$REPOSITORY_ROOT/migration/steps/CP-3D-tiles-tld-exception.md"

fail() {
  printf 'FALHA CP-3D/3.16: %s\n' "$1" >&2
  exit 1
}

for required in "$POM" "$ALLOWLIST" "$TLD" "$WEB_XML" \
  "$HANDLER" "$TASKS" "$DECISION" "$STEP"; do
  [[ -f "$required" ]] || fail "arquivo obrigatório ausente: ${required#"$REPOSITORY_ROOT/"}"
done

if grep -Fq 'https://jakarta.ee/xml/ns/jakartaee' "$WEB_XML"; then
  "$REPOSITORY_ROOT/scripts/validate-cp-3f-namespace.sh"
  printf 'INFO: exceção histórica Tiles/TLD preservada no CP-3D; namespace ativo validado pelo CP-3F\n'
  exit 0
fi

grep -Fq -- '- [x] 3.16 Manter Tiles e handlers TLD em `javax`' "$TASKS" ||
  fail 'a tarefa 3.16 não está marcada como concluída'

grep -Fq '<tiles.version>2.1.4</tiles.version>' "$POM" ||
  fail 'POM não fixa Tiles 2.1.4'
for legacy_file in "$TILES_DEFS" "$BASE_LAYOUT"; do
  [[ -f "$legacy_file" ]] || fail "arquivo Tiles legado ausente: ${legacy_file#"$REPOSITORY_ROOT/"}"
done
for coordinate in \
  '<artifactId>tiles-api</artifactId>' \
  '<artifactId>tiles-jsp</artifactId>'; do
  grep -Fq "$coordinate" "$POM" || fail "dependência Tiles ausente: $coordinate"
done

for library in \
  tiles-api-2.1.4.jar \
  tiles-core-2.1.4.jar \
  tiles-jsp-2.1.4.jar \
  tiles-servlet-2.1.4.jar; do
  grep -Fxq "$library" "$ALLOWLIST" ||
    fail "allowlist não contém $library"
done
if grep -E '^tiles-.*\.jar$' "$ALLOWLIST" |
   grep -Ev '^(tiles-api|tiles-core|tiles-jsp|tiles-servlet)-2\.1\.4\.jar$' >/dev/null; then
  fail 'allowlist contém versão ou artefato Tiles não aprovado'
fi
[[ "$(grep -Ec '^tiles-(api|core|jsp|servlet)-2\.1\.4\.jar$' "$ALLOWLIST")" == "4" ]] ||
  fail 'allowlist não contém exatamente os quatro JARs Tiles 2.1.4'

for marker in \
  'http://java.sun.com/xml/ns/j2ee' \
  'web-jsptaglibrary_2_0.xsd' \
  'version="2.0"' \
  '<tag-class>br.com.asillos.migration.web.tag.StatusPedidoTag</tag-class>'; do
  grep -Fq "$marker" "$TLD" || fail "TLD histórico não preserva: $marker"
done
grep -Fq 'javax.servlet.jsp.tagext.SimpleTagSupport' "$HANDLER" ||
  fail 'handler TLD não usa javax.servlet.jsp.tagext'
if grep -Eq 'jakarta\.servlet(\.jsp)?|jakarta\.tags' "$TLD" "$HANDLER" "$WEB_XML"; then
  fail 'namespace Jakarta foi antecipado no gate Java 17'
fi

for marker in \
  'org.apache.tiles.impl.BasicTilesContainer.DEFINITIONS_CONFIG' \
  '/WEB-INF/tiles-defs.xml' \
  'org.apache.tiles.web.startup.TilesListener'; do
  grep -Fq "$marker" "$WEB_XML" || fail "web.xml não preserva: $marker"
done
for marker in \
  'migration.base' \
  'pedidos.lista' \
  'pedidos.formulario' \
  'pedidos.detalhe' \
  'http://tiles.apache.org/tags-tiles'; do
  grep -Fq "$marker" "$TILES_DEFS" "$REPOSITORY_ROOT/app/src/main/webapp/WEB-INF/layout/base.jsp" ||
    fail "configuração Tiles não preserva: $marker"
done

for marker in \
  'exceção temporária' \
  'descontinuado' \
  'atividade 3.28' \
  'atividade 3.31' \
  '314109417c648ce9d32ab3824d24696ac7c83a94'; do
  grep -Fqi "$marker" "$DECISION" "$STEP" ||
    fail "documentação CP-3D não contém: $marker"
done

printf 'OK: CP-3D/3.16 mantém Tiles 2.1.4 e TLD javax como exceção temporária documentada\n'
