#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POM="$REPOSITORY_ROOT/app/pom.xml"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
WAR_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2c.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso: ./scripts/validate-cp-2c.sh [--war ARQUIVO]

Sem argumentos, valida estaticamente o alinhamento ao Jakarta EE 8.
Com --war, comprova também a ausência de APIs do contêiner em WEB-INF/lib.
USAGE
}

fail() {
  printf 'FALHA CP-2C: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2c.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
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
  "$POM" \
  "$EXPECTED_LIBRARIES" \
  "$REPOSITORY_ROOT/docs/cp-2c-ee8-maven-datasource.md" \
  "$REPOSITORY_ROOT/scripts/ValidateApplicationPom.java" \
  "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for marker in \
  '<jakarta.ee.web.api.version>8.0.0</jakarta.ee.web.api.version>' \
  '<groupId>jakarta.platform</groupId>' \
  '<artifactId>jakarta.jakartaee-web-api</artifactId>' \
  '<version>${jakarta.ee.web.api.version}</version>' \
  '<scope>provided</scope>'; do
  grep -Fq "$marker" "$POM" ||
    fail "POM não contém o contrato EE 8: $marker"
done

for forbidden_coordinate in \
  '<artifactId>servlet-api</artifactId>' \
  '<artifactId>jsp-api</artifactId>' \
  '<artifactId>jstl-api</artifactId>' \
  '<artifactId>javaee-web-api</artifactId>'; do
  if grep -Fq "$forbidden_coordinate" "$POM"; then
    fail "POM ainda contém API histórica separada: $forbidden_coordinate"
  fi
done

if grep -R -E \
    '^[[:space:]]*import[[:space:]]+jakarta\.(servlet|el)\.' \
    "$REPOSITORY_ROOT/app/src/main/java"; then
  fail "CP-2C não deve antecipar a migração de namespace do gate Jakarta"
fi

grep -Fq -- \
  '- [x] 2.11 Alinhar as APIs do build a Jakarta EE 8' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.11 não está concluída no OpenSpec"

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"

  awk '
    /^WEB-INF\/lib\/[^/]+\.jar$/ {
      sub(/^WEB-INF\/lib\//, "")
      print
    }
  ' "$TEMP_DIRECTORY/war-entries.txt" |
    LC_ALL=C sort >"$TEMP_DIRECTORY/actual-libraries.txt"

  if grep -Eq \
      '^WEB-INF/lib/(servlet-api|javax\.servlet-api|jakarta\.servlet-api|jsp-api|javax\.servlet\.jsp-api|jakarta\.servlet\.jsp-api|jstl-api|javax\.servlet\.jsp\.jstl-api|jakarta\.servlet\.jsp\.jstl-api|javax\.el-api|jakarta\.el-api|javaee-api|javaee-web-api|jakarta\.jakartaee-api|jakarta\.jakartaee-web-api)-[^/]+\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR contém uma API fornecida pelo WildFly"
  fi

  LC_ALL=C sort "$EXPECTED_LIBRARIES" \
    >"$TEMP_DIRECTORY/expected-libraries.txt"
  diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt" ||
    fail "WEB-INF/lib diverge da allowlist da fase 2"
fi

printf 'OK: build alinhado ao Jakarta EE Web Profile 8 em provided'
if [[ -n "$WAR_FILE" ]]; then
  printf ', sem APIs do contêiner em WEB-INF/lib'
fi
printf '\n'
