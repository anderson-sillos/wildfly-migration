#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf 'FALHA CP-3F: %s\n' "$1" >&2
  exit 1
}

required=(
  "app/pom.xml"
  "app/src/main/webapp/WEB-INF/web.xml"
  "app/src/main/webapp/WEB-INF/migration.tld"
  "migration/evidence/CP-3F/tld-historical.xml"
  "migration/evidence/CP-3F/tld-migration.properties"
  "migration/evidence/CP-3F/deployment-tiles-blocked.txt"
  "runtime/phase3/java21-wildfly41/h2/module.xml"
  "runtime/phase3/java21-wildfly41/profiles/ci-h2.cli"
  "app/src/main/java/br/com/asillos/migration/web/JakartaFileUploadRequestContext.java"
)

for path in "${required[@]}"; do
  [[ -f "$ROOT/$path" ]] || fail "arquivo obrigatório ausente: $path"
done

if rg -n '^import javax\.(servlet|el)(\.|;)' \
    "$ROOT/app/src/main/java"; then
  fail "a árvore web ainda importa APIs EE javax"
fi

if rg -n 'javax\.servlet\.context\.tempdir|http://java\.sun\.com/jsp/jstl' \
    "$ROOT/app/src/main/java" "$ROOT/app/src/main/webapp"; then
  fail "referência de namespace Servlet/JSTL legado permaneceu na aplicação"
fi

grep -Fq 'xmlns="https://jakarta.ee/xml/ns/jakartaee"' \
  "$ROOT/app/src/main/webapp/WEB-INF/web.xml" ||
  fail "web.xml não usa namespace Jakarta"
grep -Fq 'web-app_6_1.xsd' "$ROOT/app/src/main/webapp/WEB-INF/web.xml" ||
  fail "web.xml não usa o schema Jakarta EE 11"
grep -Fq 'version="6.1"' "$ROOT/app/src/main/webapp/WEB-INF/web.xml" ||
  fail "web.xml não declara Servlet 6.1"

if rg -n 'java\.sun\.com/xml/ns/j2ee|web-app_2_4\.xsd' \
    "$ROOT/app/src/main/webapp/WEB-INF/web.xml"; then
  fail "web.xml histórico foi mantido na aplicação moderna"
fi

grep -Fq 'xmlns="https://jakarta.ee/xml/ns/jakartaee"' \
  "$ROOT/app/src/main/webapp/WEB-INF/migration.tld" ||
  fail "TLD não usa namespace Jakarta"
grep -Fq 'web-jsptaglibrary_3_0.xsd' \
  "$ROOT/app/src/main/webapp/WEB-INF/migration.tld" ||
  fail "TLD não usa schema Jakarta JSP"
grep -Fq 'version="3.0"' \
  "$ROOT/app/src/main/webapp/WEB-INF/migration.tld" ||
  fail "TLD não declara versão Jakarta"
grep -Fq 'jakarta.servlet.jsp.tagext.SimpleTagSupport' \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/tag/StatusPedidoTag.java" ||
  fail "handler da tag não usa Jakarta JSP"

for uri in jakarta.tags.core jakarta.tags.fmt; do
  grep -R -Fq "uri=\"$uri\"" "$ROOT/app/src/main/webapp" ||
    fail "URI JSTL ausente: $uri"
done
if rg -n 'java\.sun\.com/jsp/jstl' "$ROOT/app/src/main/webapp"; then
  fail "URI JSTL legado permaneceu nas JSPs"
fi

grep -Fq 'historical.wildfly41.outcome=rejected-before-normalization' \
  "$ROOT/migration/evidence/CP-3F/tld-migration.properties" ||
  fail "resultado do TLD histórico não foi registrado"
grep -Fq 'historical.version=2.0' \
  "$ROOT/migration/evidence/CP-3F/tld-migration.properties" ||
  fail "versão histórica do TLD não foi preservada"
grep -Fq 'modern.version=3.0' \
  "$ROOT/migration/evidence/CP-3F/tld-migration.properties" ||
  fail "versão moderna do TLD não foi registrada"
grep -Fq 'expected Tiles javax incompatibility' \
  "$ROOT/migration/evidence/CP-3F/deployment-tiles-blocked.txt" ||
  fail "bloqueio natural do Tiles não foi registrado"

grep -Fq 'driver-module-name=com.h2database.h2' \
  "$ROOT/runtime/phase3/java21-wildfly41/profiles/ci-h2.cli" ||
  fail "perfil H2 do WildFly 41 não usa o módulo fixado do servidor"

printf 'OK: namespaces, descritores, JSTL e TLD do CP-3F validados\n'
