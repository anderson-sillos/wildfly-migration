#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBAPP="$ROOT/app/src/main/webapp"
POM="$ROOT/app/pom.xml"
WAR="$ROOT/app/target/wildfly-migration.war"

fail() {
  printf 'FALHA CP-3G/3.31: %s\n' "$1" >&2
  exit 1
}

required=(
  "app/pom.xml"
  "app/src/main/webapp/WEB-INF/web.xml"
  "app/src/main/webapp/WEB-INF/tags/layout/page.tag"
  "app/src/main/webapp/WEB-INF/layout/header.jsp"
  "app/src/main/webapp/WEB-INF/layout/footer.jsp"
  "app/src/main/webapp/WEB-INF/views/erro.jsp"
  "app/src/main/webapp/WEB-INF/views/pedidos/lista.jsp"
  "app/src/main/webapp/WEB-INF/views/pedidos/formulario.jsp"
  "app/src/main/webapp/WEB-INF/views/pedidos/detalhe.jsp"
  "app/src/main/webapp/WEB-INF/views/pedidos/importacao-xml.jsp"
)
for path in "${required[@]}"; do
  [[ -f "$ROOT/$path" ]] || fail "arquivo obrigatório ausente: $path"
done

[[ ! -e "$WEBAPP/WEB-INF/tiles-defs.xml" ]] ||
  fail 'tiles-defs.xml ainda está no WAR'
[[ ! -e "$WEBAPP/WEB-INF/layout/base.jsp" ]] ||
  fail 'layout/base.jsp ainda usa o template Tiles'

if rg -n -i 'tiles|org\.apache\.tiles|tiles-defs' "$WEBAPP" "$POM"; then
  fail 'referência Tiles permaneceu na aplicação moderna'
fi

grep -Fq 'jakarta.tags.core' "$WEBAPP/WEB-INF/tags/layout/page.tag" ||
  fail 'tag file não usa JSTL Jakarta'
grep -Fq '<jsp:include page="/WEB-INF/layout/header.jsp"/>' \
  "$WEBAPP/WEB-INF/tags/layout/page.tag" ||
  fail 'tag file não inclui o cabeçalho compartilhado'
grep -Fq '<jsp:include page="${contentPage}"/>' \
  "$WEBAPP/WEB-INF/tags/layout/page.tag" ||
  fail 'tag file não inclui a página de conteúdo'
grep -Fq '<jsp:include page="/WEB-INF/layout/footer.jsp"/>' \
  "$WEBAPP/WEB-INF/tags/layout/page.tag" ||
  fail 'tag file não inclui o rodapé compartilhado'

for view in \
  "$WEBAPP/WEB-INF/views/erro.jsp" \
  "$WEBAPP/WEB-INF/views/pedidos/lista.jsp" \
  "$WEBAPP/WEB-INF/views/pedidos/formulario.jsp" \
  "$WEBAPP/WEB-INF/views/pedidos/detalhe.jsp" \
  "$WEBAPP/WEB-INF/views/pedidos/importacao-xml.jsp"; do
  grep -Fq 'tagdir="/WEB-INF/tags/layout"' "$view" ||
    fail "view não usa o tag file de layout: ${view#"$ROOT/"}"
  grep -Fq '<layout:page ' "$view" ||
    fail "view não invoca layout:page: ${view#"$ROOT/"}"
done

if [[ -f "$WAR" ]]; then
  jar tf "$WAR" | grep -Eiq '(^|/)(tiles(-|\.)|tiles-defs\.xml)' &&
    fail 'WAR contém artefato ou configuração Tiles'
  jar tf "$WAR" | grep -Fq 'WEB-INF/tags/layout/page.tag' ||
    fail 'WAR não contém o tag file de layout'
fi

printf 'OK: CP-3G/3.31 remove Tiles e usa tag file JSP com includes protegidos\n'
