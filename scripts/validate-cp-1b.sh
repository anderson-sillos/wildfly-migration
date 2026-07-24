#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1b.XXXXXXXX")"
RELEASE_MODE=false

if [[ "${1:-}" == "--release" ]]; then
  RELEASE_MODE=true
  shift
fi

if [[ $# -ne 0 ]]; then
  printf 'Uso: ./scripts/validate-cp-1b.sh [--release]\n' >&2
  exit 2
fi

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1b.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada: %s\n' \
        "$TEMP_DIRECTORY" >&2
      ;;
  esac
}
trap cleanup EXIT

required_paths=(
  "app/src/main/java"
  "app/src/main/resources"
  "app/src/main/webapp/WEB-INF"
  "app/src/test/java"
  "app/src/test/resources"
  "contract-tests/fixtures"
  "runtime/legacy/runtime-manifest.tsv"
  "migration/steps"
  "docs/legacy-domain-model.md"
)

for path in "${required_paths[@]}"; do
  if [[ ! -e "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: caminho obrigatório ausente: %s\n' "$path" >&2
    exit 1
  fi
done

if [[ -e "$REPOSITORY_ROOT/app/pom.xml" ]]; then
  printf 'FALHA: app/pom.xml pertence ao CP-1C, não ao CP-1B\n' >&2
  exit 1
fi

awk -F '\t' '
  NR == 1 {
    expected = "component\tversion\tarchive\torigin\tlicense\tsha256\tsha512"
    if ($0 != expected) {
      print "FALHA: cabeçalho inválido no manifesto legado" > "/dev/stderr"
      exit 1
    }
    next
  }
  NF != 7 {
    print "FALHA: registro inválido no manifesto legado: linha " NR > "/dev/stderr"
    exit 1
  }
  {
    count[$1]++
  }
  END {
    if (count["oracle-jdk"] != 1 ||
        count["apache-maven"] != 1 ||
        count["wildfly"] != 1) {
      print "FALHA: componentes esperados não são únicos no manifesto" > "/dev/stderr"
      exit 1
    }
  }
' "$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"

if [[ "$RELEASE_MODE" == true ]] &&
   rg -q 'PENDING_|TO_BE_DEFINED|CHANGE_ME' \
     "$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"; then
  printf 'FALHA: manifesto legado ainda contém valor pendente\n' >&2
  exit 1
fi

for sql_file in 001_schema.sql rollback.sql; do
  if ! rg -q '(^|[[:space:]])/$' \
      "$REPOSITORY_ROOT/app/src/main/resources/db/oracle/$sql_file"; then
    printf 'FALHA: terminador SQL*Plus ausente em %s\n' "$sql_file" >&2
    exit 1
  fi
done

if ! rg -q '^MERGE INTO LAB_PEDIDO ' \
    "$REPOSITORY_ROOT/app/src/main/resources/db/oracle/002_seed.sql" ||
   ! rg -q '^COMMIT;$' \
    "$REPOSITORY_ROOT/app/src/main/resources/db/oracle/002_seed.sql"; then
  printf 'FALHA: script de massa idempotente está incompleto\n' >&2
  exit 1
fi

javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY" \
  "$REPOSITORY_ROOT/scripts/ValidateXmlFixtures.java"
java -cp "$TEMP_DIRECTORY" ValidateXmlFixtures "$REPOSITORY_ROOT"

printf 'OK: estrutura e recursos estáticos do CP-1B validados\n'
