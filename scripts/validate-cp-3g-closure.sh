#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$ROOT/migration/evidence/CP-3G"
WAR=""

usage() {
  printf '%s\n' \
    'Uso: ./scripts/validate-cp-3g-closure.sh [--war ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3G/3.35: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail '--war exige um arquivo'
      WAR="$2"
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

for path in \
  "$ROOT/docs/evidence/CP-3G.md" \
  "$ROOT/migration/steps/CP-3G-tiles-jsp-layout.md" \
  "$ROOT/migration/steps/CP-3G-servlet-multipart.md" \
  "$ROOT/migration/steps/CP-3G-servlet-container-initializer.md" \
  "$ROOT/migration/steps/CP-3G-slf4j-mybatis.md" \
  "$EVIDENCE/closure.properties" \
  "$EVIDENCE/rollback.properties" \
  "$EVIDENCE/upload-ci-h2.json" \
  "$EVIDENCE/upload-oracle.json" \
  "$EVIDENCE/discovery-ci-h2.json" \
  "$EVIDENCE/logging-ci-h2.json"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

property() {
  local key="$1"
  sed -n "s/^${key}=//p" "$EVIDENCE/closure.properties" | head -n 1
}

for marker in \
  'schema=wildfly-migration-cp3g-closure/v1' \
  'checkpoint=CP-3G' \
  'workingTree=false' \
  'portable-ci.contract.scenarios=15' \
  'portable-ci.result=passed' \
  'portable-ci.layout.audit=passed' \
  'portable-ci.multipart.audit=passed' \
  'portable-ci.discovery.audit=passed' \
  'portable-ci.logging.audit=passed' \
  'portable-ci.dependency.audit=passed' \
  'portable-ci.security.audit=passed' \
  'oracle-qualified.upload.scenarios=15' \
  'oracle-qualified.upload.result=passed' \
  'result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE/closure.properties" ||
    fail "fechamento não contém: $marker"
done

tested_commit="$(property tested.commit)"
[[ "$tested_commit" =~ ^[0-9a-f]{40}$ ]] ||
  fail 'commit-fonte do fechamento não é um SHA-1 completo'
git -C "$ROOT" cat-file -e "$tested_commit^{commit}" 2>/dev/null ||
  fail 'commit-fonte do fechamento não existe no repositório'

for report in \
  "$EVIDENCE/upload-ci-h2.json" \
  "$EVIDENCE/upload-oracle.json" \
  "$EVIDENCE/discovery-ci-h2.json" \
  "$EVIDENCE/logging-ci-h2.json"; do
  grep -Fq '"workingTree": false' "$report" ||
    fail "evidência sem workingTree=false: ${report##*/}"
  grep -Fq '"result": "passed"' "$report" ||
    fail "evidência não aprovada: ${report##*/}"
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' \
      "$report"; then
    fail "evidência contém configuração sensível: ${report##*/}"
  fi
done

for marker in \
  'schema=wildfly-migration-cp3g-rollback/v1' \
  'checkpoint=CP-3G' \
  'rollback.target=CP-3F' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documented-checkout'; do
  grep -Fxq "$marker" "$EVIDENCE/rollback.properties" ||
    fail "rollback não contém: $marker"
done

"$ROOT/scripts/validate-cp-3g-tiles.sh"
"$ROOT/scripts/validate-cp-3g-upload.sh"
"$ROOT/scripts/validate-cp-3g-discovery.sh"
if [[ -n "$WAR" ]]; then
  "$ROOT/scripts/validate-cp-3g-logging.sh" --war "$WAR"
else
  "$ROOT/scripts/validate-cp-3g-logging.sh"
fi

if grep -REiq \
    'tiles|org\.apache\.tiles|commons\.fileupload|ServletFileUpload|org\.reflections|LegacyValidatorDiscovery|log4j-over-slf4j|<artifactId>log4j</artifactId>' \
    "$ROOT/app/pom.xml" "$ROOT/app/src/main/java" "$ROOT/app/src/main/resources" "$ROOT/app/src/main/webapp"; then
  fail 'dependência ou referência removida permanece no código ativo'
fi

if [[ -n "$WAR" ]]; then
  [[ -f "$WAR" ]] || fail "WAR não encontrado: $WAR"
  entries="$(mktemp)"
  trap 'rm -f "$entries"' EXIT
  jar tf "$WAR" >"$entries"
  if grep -Eiq '^WEB-INF/lib/(tiles|commons-fileupload|reflections|log4j-over-slf4j|slf4j-api|logback|log4j-core)' "$entries"; then
    fail 'WAR contém biblioteca removida ou backend concorrente'
  fi
fi

printf 'OK: CP-3G encerrado; contratos, SCI, logging, WAR, dependências e rollback válidos\n'
