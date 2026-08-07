#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/migration/incompatibilities.tsv"
FIXTURES="$ROOT/migration/incompatibility-fixtures.tsv"
DOC="$ROOT/migration/incompatibility-catalog.md"

fail() {
  printf 'FALHA catálogo de incompatibilidades: %s\n' "$1" >&2
  exit 1
}

for path in "$CATALOG" "$FIXTURES" "$DOC" "$ROOT/migration/incompatibility-template.md"; do
  [[ -f "$path" ]] || fail "arquivo ausente: ${path#"$ROOT/"}"
done

header=$'id\tcheckpoint\tsource\ttarget\tstage\tcategory\treproduction\tstatus\trecord'
[[ "$(head -n 1 "$CATALOG")" == "$header" ]] || fail 'cabeçalho do catálogo diverge'
fixture_header=$'id\tcatalog_id\tfixture\tpurpose\treason\tenabled_by_default\trecord'
[[ "$(head -n 1 "$FIXTURES")" == "$fixture_header" ]] || fail 'cabeçalho de fixtures diverge'

declare -A catalog_ids=()
line_number=1
while IFS=$'\t' read -r id checkpoint source target stage category reproduction status record trailing ||
      [[ -n "${id:-}${checkpoint:-}${source:-}${target:-}${stage:-}${category:-}${reproduction:-}${status:-}${record:-}${trailing:-}" ]]; do
  line_number=$((line_number + 1))
  [[ -z "${trailing:-}" ]] || fail "coluna extra no catálogo, linha $line_number"
  [[ "$id" =~ ^INC-[0-9]{3}$ ]] || fail "ID inválido na linha $line_number"
  [[ -z "${catalog_ids[$id]+present}" ]] || fail "ID duplicado: $id"
  catalog_ids["$id"]=1
  [[ "$checkpoint" =~ ^CP-[123][A-Z]$ ]] || fail "checkpoint inválido: $id"
  [[ "$stage" =~ ^(compilation|packaging|deployment|startup|configuration|execution|verification)$ ]] ||
    fail "etapa inválida: $id"
  [[ "$reproduction" == natural || "$reproduction" == fixture-opt-in ]] ||
    fail "reprodução inválida: $id"
  [[ "$status" == resolved || "$status" == observed || "$status" == blocked ]] ||
    fail "estado inválido: $id"
  [[ -f "$ROOT/$record" ]] || fail "registro ausente para $id: $record"
done < <(tail -n +2 "$CATALOG")

declare -A fixture_ids=()
line_number=1
while IFS=$'\t' read -r id catalog_id fixture purpose reason enabled record trailing ||
      [[ -n "${id:-}${catalog_id:-}${fixture:-}${purpose:-}${reason:-}${enabled:-}${record:-}${trailing:-}" ]]; do
  line_number=$((line_number + 1))
  [[ -z "${trailing:-}" ]] || fail "coluna extra nas fixtures, linha $line_number"
  [[ "$id" =~ ^FIX-[0-9]{3}$ ]] || fail "ID de fixture inválido: $id"
  [[ -z "${fixture_ids[$id]+present}" ]] || fail "fixture duplicada: $id"
  fixture_ids["$id"]=1
  [[ -n "${catalog_ids[$catalog_id]+present}" ]] || fail "catálogo ausente para fixture $id"
  [[ "$enabled" == false ]] || fail "fixture não é opt-in: $id"
  [[ -f "$ROOT/$fixture" ]] || fail "arquivo de fixture ausente: $fixture"
  [[ -f "$ROOT/$record" ]] || fail "registro de fixture ausente: $record"
  grep -Fq "$catalog_id" "$CATALOG" || fail "fixture sem linha do catálogo: $id"
done < <(tail -n +2 "$FIXTURES")

for marker in \
  'Java-' 'Jakarta' 'WAR' 'Tiles' 'TLD' 'FileUpload' 'Log4j' 'MyBatis' \
  'Reflections' 'ServletContainerInitializer' 'ojdbc' 'XMLBeans' 'xml-apis' \
  'StAX' 'dom4j'; do
  grep -Fqi "$marker" "$CATALOG" || fail "cobertura mínima ausente: $marker"
done

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=|senha' \
    "$CATALOG" "$FIXTURES" "$DOC"; then
  fail 'catálogo contém configuração sensível'
fi

printf 'OK: catálogo validado (%d incompatibilidades, %d fixtures opt-in)\n' \
  "${#catalog_ids[@]}" "${#fixture_ids[@]}"
