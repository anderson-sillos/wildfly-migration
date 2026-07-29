#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv"
EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-2B/before-deployment.properties"
WAR_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2b.XXXXXXXX"
)"

fail() {
  printf 'FALHA CP-2B: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2b.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

if [[ $# -gt 0 ]]; then
  [[ "$1" == "--war" && $# -eq 2 ]] ||
    fail "uso: ./scripts/validate-cp-2b.sh [--war ARQUIVO]"
  WAR_FILE="$2"
fi

for path in \
  "$MANIFEST" \
  "$EVIDENCE" \
  "$REPOSITORY_ROOT/docs/cp-2b-wildfly26.md" \
  "$REPOSITORY_ROOT/docs/evidence/CP-2B.md" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/README.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-2B-wildfly26-missing-datasource.md"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for marker in \
  'source.commit=bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0' \
  'source.war.sha256=bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4' \
  'source.bytecode.major=52' \
  'code.changed=false' \
  'war.changed=false' \
  'deployment.status=FAILED' \
  'health.http-status=404' \
  'migration.datasource.present=false' \
  'result=expected-failure' \
  'failure.signature=javax.naming.NameNotFoundException-jdbc/MigrationDS'; do
  grep -Fxq "$marker" "$EVIDENCE" ||
    fail "evidência anterior à correção não contém: $marker"
done

grep -Fq $'INC-007\tCP-2B\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-007 não foi catalogada"
grep -Fq -- '- [x] 2.6 Tentar implantar no WildFly 26.1.3' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.6 não está concluída"

expected_wildfly_row=$'wildfly-community\t26.1.3.Final\twildfly-26.1.3.Final.tar.gz\thttps://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.tar.gz\tLGPL-2.1-or-later\taadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59\tsha1:b9f52ba41df890e09bb141d72947d2510caf758c\tEOL-bridge-runtime\tCP-2B-and-CP-3A-to-CP-3D'
[[ "$(sed -n '3p' "$MANIFEST")" == "$expected_wildfly_row" ]] ||
  fail "registro WildFly 26 não corresponde à distribuição fixada"

grep -Fxq \
  'WILDFLY26_ARCHIVE_SHA256=aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59' \
  "$REPOSITORY_ROOT/.env.example" ||
  fail ".env.example não contém o SHA-256 fixado do WildFly 26"

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  [[ "$(sha256sum "$WAR_FILE" | awk '{print $1}')" == \
    "bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4" ]] ||
    fail "WAR informado não é o artefato aprovado no CP-2A"
  unzip -p "$WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class \
    >"$TEMP_DIRECTORY/LegacyBuildMarker.class"
  javap -verbose "$TEMP_DIRECTORY/LegacyBuildMarker.class" |
    grep -Fq 'major version: 52' ||
    fail "WAR informado não contém bytecode Java 8 major 52"
fi

printf 'OK: tentativa sem correção do WAR CP-2A no WildFly 26 está registrada'
if [[ -n "$WAR_FILE" ]]; then
  printf ', WAR aprovado preservado'
fi
printf '\n'
