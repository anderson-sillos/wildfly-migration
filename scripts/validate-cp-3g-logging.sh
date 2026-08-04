#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR=""
SERVER_LOG=""
EVIDENCE="$ROOT/migration/evidence/CP-3G/logging-ci-h2.json"

usage() {
  printf '%s\n' \
    'Uso: ./scripts/validate-cp-3g-logging.sh [--war ARQUIVO] [--server-log ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3G/3.34: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail '--war exige um arquivo'
      WAR="$2"
      shift 2
      ;;
    --server-log)
      [[ $# -ge 2 ]] || fail '--server-log exige um arquivo'
      SERVER_LOG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

POM="$ROOT/app/pom.xml"
MYBATIS_CONFIG="$ROOT/app/src/main/resources/mybatis-config.xml"
DEPLOYMENT="$ROOT/app/src/main/webapp/WEB-INF/jboss-deployment-structure.xml"
CI_PROFILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/ci-h2.cli"
ORACLE_PROFILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/oracle.cli"

for path in \
  "$POM" \
  "$MYBATIS_CONFIG" \
  "$DEPLOYMENT" \
  "$CI_PROFILE" \
  "$ORACLE_PROFILE" \
  "$ROOT/migration/steps/CP-3G-slf4j-mybatis.md" \
  "$EVIDENCE"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

grep -Fq '<artifactId>slf4j-api</artifactId>' "$POM" ||
  fail 'API SLF4J não está declarada'
grep -Fq '<slf4j.version>2.0.18</slf4j.version>' "$POM" ||
  fail 'POM não fixa a API SLF4J compatível com WildFly 41'
grep -A3 -Fq '<artifactId>slf4j-api</artifactId>' "$POM" ||
  fail 'dependência SLF4J não está configurada'
if grep -Eiq 'log4j-over-slf4j|<artifactId>log4j</artifactId>|<groupId>log4j</groupId>' \
    "$POM"; then
  fail 'ponte ou Log4j 1 ainda aparece no POM ativo'
fi
grep -Fq '<setting name="logImpl" value="SLF4J"/>' "$MYBATIS_CONFIG" ||
  fail 'MyBatis não fixa logImpl=SLF4J'

for source in \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/RequestContextFilter.java" \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/UploadServlet.java" \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java" \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/PedidoServlet.java" \
  "$ROOT/app/src/main/java/br/com/asillos/migration/integration/xml/LegacyPedidoXmlParser.java"; do
  grep -Fq 'org.slf4j' "$source" ||
    fail "classe não usa SLF4J: ${source#"$ROOT/"}"
  if grep -Fq 'org.apache.log4j' "$source"; then
    fail "classe ainda usa Log4j 1: ${source#"$ROOT/"}"
  fi
done
if grep -REn 'org\.apache\.log4j|log4j-over-slf4j' \
    "$ROOT/app/src/main/java" "$ROOT/app/src/main/resources"; then
  fail 'referência ativa à ponte ou à API Log4j 1 encontrada'
fi

for profile in "$CI_PROFILE" "$ORACLE_PROFILE"; do
  grep -Fq 'br.com.asillos.migration.persistence:add(level=TRACE' "$profile" ||
    fail "perfil sem categoria DEBUG dos mappers: ${profile##*/}"
  grep -Fq 'org.apache.ibatis:add(level=TRACE' "$profile" ||
    fail "perfil sem categoria DEBUG do MyBatis: ${profile##*/}"
  grep -Fq '%X{correlationId}' "$profile" ||
    fail "perfil sem MDC de correlação: ${profile##*/}"
done

for marker in \
  '"schema": "wildfly-migration-cp3g-logging/v1"' \
  '"activity": "3.34"' \
  '"mybatisLogImpl": "SLF4J"' \
  '"bridge": "absent"' \
  '"mapperCategories": "passed"' \
  '"exceptionStackTrace": "passed"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$EVIDENCE" ||
    fail "evidência de logging não contém: $marker"
done

if [[ -n "$WAR" ]]; then
  [[ -f "$WAR" ]] || fail "WAR não encontrado: $WAR"
  entries="$(mktemp)"
  trap 'rm -f -- "$entries"' EXIT
  unzip -Z1 "$WAR" >"$entries"
  if grep -Eiq \
      '^WEB-INF/lib/(log4j-over-slf4j|log4j-1|slf4j-api|slf4j-simple|slf4j-log4j12|logback-classic|log4j-core)[^/]*\.jar$' \
      "$entries"; then
    fail 'WAR contém ponte, API SLF4J duplicada ou backend concorrente'
  fi
  grep -Fq 'WEB-INF/classes/mybatis-config.xml' "$entries" ||
    fail 'WAR não contém mybatis-config.xml'
fi

if [[ -n "$SERVER_LOG" ]]; then
  [[ -f "$SERVER_LOG" ]] || fail "server.log não encontrado: $SERVER_LOG"
  grep -Fq 'br.com.asillos.migration.persistence.PedidoMapper' "$SERVER_LOG" ||
    fail 'server.log não comprova a categoria do PedidoMapper'
  grep -Fq 'br.com.asillos.migration.persistence.AnexoMapper' "$SERVER_LOG" ||
    fail 'server.log não comprova a categoria do AnexoMapper'
  grep -Fq 'legacy_order persistence_failure' "$SERVER_LOG" ||
    fail 'server.log não contém a falha controlada do pedido'
  awk '
    /legacy_order persistence_failure/ { window=25; found=1 }
    window > 0 {
      if ($0 ~ /Exception|Error/ || $0 ~ /^[[:space:]]+at /) stack=1
      window--
    }
    END { exit(found && stack ? 0 : 1) }
  ' "$SERVER_LOG" || fail 'server.log não contém stack trace completo da exceção'
  if grep -Eiq 'SLF4J:.*multiple|log4j:WARN|WFLYLOG0100' "$SERVER_LOG"; then
    fail 'server.log registra conflito ou configuração Log4j depreciada'
  fi
fi

printf 'OK: CP-3G/3.34 remove a ponte, fixa MyBatis em SLF4J e valida logging do WildFly\n'
