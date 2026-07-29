#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIRECTORY="$REPOSITORY_ROOT/migration/baselines/01-legacy"
PROPERTIES_FILE="$BASELINE_DIRECTORY/baseline.properties"
SCENARIOS_FILE="$BASELINE_DIRECTORY/contract-scenarios.tsv"
ORACLE_STATE_FILE="$BASELINE_DIRECTORY/oracle-persisted-state.tsv"
COMPONENTS_FILE="$BASELINE_DIRECTORY/components.tsv"
DEPENDENCIES_FILE="$BASELINE_DIRECTORY/maven-dependencies.tsv"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt"
INCOMPATIBILITIES_FILE="$REPOSITORY_ROOT/migration/incompatibilities.tsv"
WAR_FILE=""
CONTRACT_RESULTS=()
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1g.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-1g-baseline.sh \
    [--war ARQUIVO] [--contract-result ARQUIVO]...

Sem argumentos, valida somente os arquivos congelados. Com --war, compara o
WAR e a árvore Maven gerada pelo build. Cada --contract-result deve ser um
relatório sanitizado produzido pela suíte HTTP externa.
USAGE
}

fail() {
  printf 'FALHA baseline CP-1G: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1g.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

property() {
  local key="$1"
  local count
  local value

  count="$(awk -F= -v wanted="$key" '$1 == wanted { count++ } END { print count + 0 }' \
    "$PROPERTIES_FILE")"
  [[ "$count" == "1" ]] || fail "propriedade ausente ou duplicada: $key"
  value="$(awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, ""); print }' \
    "$PROPERTIES_FILE")"
  [[ -n "$value" ]] || fail "propriedade vazia: $key"
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --contract-result)
      [[ $# -ge 2 ]] || fail "--contract-result exige um arquivo"
      CONTRACT_RESULTS+=("$2")
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

for required in \
  "$PROPERTIES_FILE" \
  "$SCENARIOS_FILE" \
  "$ORACLE_STATE_FILE" \
  "$COMPONENTS_FILE" \
  "$DEPENDENCIES_FILE" \
  "$EXPECTED_LIBRARIES" \
  "$REPOSITORY_ROOT/docs/h2-oracle-differences.md" \
  "$INCOMPATIBILITIES_FILE" \
  "$REPOSITORY_ROOT/migration/incompatibility-template.md"; do
  [[ -f "$required" ]] || fail "arquivo obrigatório ausente: ${required#"$REPOSITORY_ROOT/"}"
done

[[ "$(head -n 1 "$INCOMPATIBILITIES_FILE")" == \
  $'id\tcheckpoint\tsource\ttarget\tstage\tcategory\treproduction\tstatus\trecord' ]] ||
  fail "cabeçalho do catálogo de incompatibilidades divergente"
if ! awk -F '\t' '
  NR > 1 {
    if (NF != 9 || $1 !~ /^INC-[0-9][0-9][0-9]$/ || seen[$1]++ ||
        $2 !~ /^CP-[123][A-Z]$/ ||
        ($5 != "compilation" && $5 != "packaging" &&
         $5 != "deployment" && $5 != "execution") ||
        ($7 != "natural" && $7 != "fixture-opt-in") ||
        ($8 != "observed" && $8 != "resolved") ||
        $9 !~ /^migration\/steps\/[A-Za-z0-9._-]+\.md$/) {
      exit 1
    }
  }
' "$INCOMPATIBILITIES_FILE"; then
  fail "catálogo de incompatibilidades possui registro inválido"
fi
while IFS=$'\t' read -r _ _ _ _ _ _ _ _ record; do
  [[ "$record" == "record" ]] && continue
  [[ -f "$REPOSITORY_ROOT/$record" ]] ||
    fail "registro do catálogo não existe: $record"
done <"$INCOMPATIBILITIES_FILE"
for marker in \
  'Tentativa antes da correção' \
  'Assinatura sanitizada' \
  'Causa-raiz' \
  'Menor correção' \
  'Evidências antes e depois' \
  'Aplicação equivalente no sistema real' \
  'Teste de regressão' \
  'Rollback'; do
  grep -Fq "$marker" "$REPOSITORY_ROOT/migration/incompatibility-template.md" ||
    fail "template de incompatibilidade perdeu a seção: $marker"
done

[[ "$(property schema)" == "wildfly-migration-baseline/v1" ]] ||
  fail "schema do baseline divergente"
[[ "$(property phase)" == "1" ]] || fail "fase congelada divergente"
[[ "$(property checkpoint)" == "CP-1G" ]] ||
  fail "checkpoint congelado divergente"
[[ "$(property tag)" == "migration/01-legacy-baseline" ]] ||
  fail "tag pública divergente"

WAR_SHA256="$(property war.sha256)"
TREE_SHA256="$(property maven.tree.sha256)"
[[ "$WAR_SHA256" =~ ^[[:xdigit:]]{64}$ ]] ||
  fail "checksum congelado do WAR inválido"
[[ "$TREE_SHA256" =~ ^[[:xdigit:]]{64}$ ]] ||
  fail "checksum congelado da árvore Maven inválido"

[[ "$(head -n 1 "$SCENARIOS_FILE")" == \
  $'scenario\tresult\tnormalized_observation' ]] ||
  fail "cabeçalho dos contratos normalizados divergente"
[[ "$(head -n 1 "$ORACLE_STATE_FILE")" == \
  $'area\tkey\texpected\tnormalization' ]] ||
  fail "cabeçalho do estado Oracle divergente"
[[ "$(head -n 1 "$COMPONENTS_FILE")" == \
  $'component\tversion\tusage\tartifact\tsha256\torigin\tlicense\tprovenance' ]] ||
  fail "cabeçalho dos componentes divergente"
[[ "$(head -n 1 "$DEPENDENCIES_FILE")" == \
  $'groupId\tartifactId\tversion\tscope\trelation\tpackaged\twarFile\tsha256\torigin\tlicense\tlicenseEvidence' ]] ||
  fail "cabeçalho das dependências divergente"

SCENARIO_COUNT="$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
  "$SCENARIOS_FILE")"
[[ "$SCENARIO_COUNT" == "$(property contract.scenarioCount)" ]] ||
  fail "quantidade de cenários normalizados divergente"
if ! awk -F '\t' '
  NR > 1 {
    if (NF != 3 || $1 !~ /^[A-Za-z][A-Za-z0-9]*$/ ||
        $2 != "passed" || $3 == "" || seen[$1]++) {
      exit 1
    }
  }
' "$SCENARIOS_FILE"; then
  fail "cenários normalizados incompletos, duplicados ou inválidos"
fi

if ! awk -F '\t' '
  NR > 1 {
    if (NF != 4 || $1 == "" || $2 == "" || $3 == "" || $4 == "") {
      exit 1
    }
  }
' "$ORACLE_STATE_FILE"; then
  fail "estado Oracle de referência está incompleto"
fi
grep -Fq $'database\treleaseUpdate\t19.3.0.0.0\t' "$ORACLE_STATE_FILE" ||
  fail "RU Oracle de referência ausente"
grep -Fq $'seed\tvalorTotal\t125.50\t' "$ORACLE_STATE_FILE" ||
  fail "valor monetário canônico ausente"

COMPONENT_COUNT="$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
  "$COMPONENTS_FILE")"
[[ "$COMPONENT_COUNT" == "7" ]] ||
  fail "manifesto deve conter sete componentes de runtime e teste"
if ! awk -F '\t' '
  NR > 1 {
    if (NF != 8 || $1 == "" || $2 == "" || $3 == "" || $4 == "" ||
        $5 == "" || $6 == "" || $7 == "" || $8 == "" || seen[$1]++) {
      exit 1
    }
    if ($4 != "external-instance" && $5 !~ /^[0-9a-f]{64}$/) {
      exit 1
    }
    if ($4 == "external-instance" && $5 != "-") {
      exit 1
    }
  }
' "$COMPONENTS_FILE"; then
  fail "manifesto de componentes está incompleto ou possui checksum inválido"
fi

{
  awk -F '\t' '
    NR > 1 {
      print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6
    }
  ' "$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"
  awk -F '\t' '
    NR > 1 {
      print $1 "\t" $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6
    }
  ' "$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
} | LC_ALL=C sort >"$TEMP_DIRECTORY/source-components.tsv"
awk -F '\t' '
  NR > 1 && ($8 == "runtime/legacy/runtime-manifest.tsv" ||
             $8 == "runtime/legacy/portable-runtime-manifest.tsv") {
    print $1 "\t" $2 "\t" $4 "\t" $6 "\t" $7 "\t" $5
  }
' "$COMPONENTS_FILE" | LC_ALL=C sort >"$TEMP_DIRECTORY/baseline-components.tsv"
if ! diff -u "$TEMP_DIRECTORY/source-components.tsv" \
    "$TEMP_DIRECTORY/baseline-components.tsv"; then
  fail "componentes congelados divergem dos manifestos de runtime"
fi

DEPENDENCY_COUNT="$(awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
  "$DEPENDENCIES_FILE")"
PACKAGED_COUNT="$(awk -F '\t' 'NR > 1 && $6 == "true" { count++ } END { print count + 0 }' \
  "$DEPENDENCIES_FILE")"
PROVIDED_COUNT="$(awk -F '\t' 'NR > 1 && $4 == "provided" { count++ } END { print count + 0 }' \
  "$DEPENDENCIES_FILE")"
[[ "$DEPENDENCY_COUNT" == "$(property maven.dependencyCount)" ]] ||
  fail "quantidade de dependências Maven divergente"
[[ "$PACKAGED_COUNT" == "$(property war.libraryCount)" ]] ||
  fail "quantidade de dependências empacotadas divergente"
[[ "$PROVIDED_COUNT" == "4" ]] ||
  fail "quatro APIs provided eram esperadas"

if ! awk -F '\t' '
  NR > 1 {
    key = $1 ":" $2
    if (NF != 11 || seen[key]++ ||
        $1 == "" || $2 == "" || $3 == "" ||
        ($4 != "compile" && $4 != "provided") ||
        ($5 != "direct" && $5 != "transitive") ||
        ($6 != "true" && $6 != "false") ||
        $8 !~ /^[0-9a-f]{64}$/ || $9 !~ /^https:\/\// ||
        $10 == "" || $11 == "") {
      exit 1
    }
    if (($6 == "true" && $7 !~ /\.jar$/) ||
        ($6 == "false" && $7 != "-")) {
      exit 1
    }
  }
' "$DEPENDENCIES_FILE"; then
  fail "inventário Maven possui registro incompleto ou inválido"
fi

awk -F '\t' 'NR > 1 && $6 == "true" { print $7 }' "$DEPENDENCIES_FILE" |
  LC_ALL=C sort >"$TEMP_DIRECTORY/manifest-libraries.txt"
LC_ALL=C sort "$EXPECTED_LIBRARIES" >"$TEMP_DIRECTORY/expected-libraries.txt"
if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/manifest-libraries.txt"; then
  fail "inventário Maven e allowlist de WEB-INF/lib divergem"
fi

for marker in \
  'tipos, constraints, sequences, timestamps e' \
  'LOB binário' \
  'H2 nunca decide qual comportamento prevalece'; do
  grep -Fq "$marker" "$REPOSITORY_ROOT/docs/h2-oracle-differences.md" ||
    fail "matriz H2/Oracle perdeu o marcador: $marker"
done

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  ACTUAL_WAR_SHA256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  [[ "$ACTUAL_WAR_SHA256" == "$WAR_SHA256" ]] ||
    fail "WAR construído diverge do checksum congelado"

  TREE_PATH="$REPOSITORY_ROOT/$(property maven.tree.path)"
  [[ -f "$TREE_PATH" ]] || fail "árvore Maven gerada não existe"
  [[ "$(sha256sum "$TREE_PATH" | awk '{print $1}')" == "$TREE_SHA256" ]] ||
    fail "árvore Maven gerada diverge do checksum congelado"

  awk -F '\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 "\t" $4 }' \
    "$DEPENDENCIES_FILE" | LC_ALL=C sort >"$TEMP_DIRECTORY/manifest-tree.tsv"
  awk '
    NR > 1 {
      line = $0
      sub(/^[|[:space:]]+/, "", line)
      sub(/^\+\- /, "", line)
      sub(/^\\- /, "", line)
      count = split(line, field, ":")
      if (count >= 5) {
        print field[1] "\t" field[2] "\t" field[4] "\t" field[5]
      }
    }
  ' "$TREE_PATH" | LC_ALL=C sort >"$TEMP_DIRECTORY/generated-tree.tsv"
  if ! diff -u "$TEMP_DIRECTORY/manifest-tree.tsv" \
    "$TEMP_DIRECTORY/generated-tree.tsv"; then
    fail "coordenadas da árvore Maven divergem do inventário congelado"
  fi

  unzip -Z1 "$WAR_FILE" |
    awk '
      /^WEB-INF\/lib\/[^/]+\.jar$/ {
        sub(/^WEB-INF\/lib\//, "")
        print
      }
    ' | LC_ALL=C sort >"$TEMP_DIRECTORY/war-libraries.txt"
  if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/war-libraries.txt"; then
    fail "WEB-INF/lib real diverge do inventário congelado"
  fi

  unzip -qq "$WAR_FILE" 'WEB-INF/lib/*.jar' -d "$TEMP_DIRECTORY/extracted"
  while IFS=$'\t' read -r _ _ _ _ _ packaged war_file expected_sha _; do
    [[ "$packaged" == "packaged" || "$packaged" == "false" ]] && continue
    ACTUAL_LIBRARY_SHA="$(
      sha256sum "$TEMP_DIRECTORY/extracted/WEB-INF/lib/$war_file" |
        awk '{print $1}'
    )"
    [[ "$ACTUAL_LIBRARY_SHA" == "$expected_sha" ]] ||
      fail "checksum do JAR empacotado diverge: $war_file"
  done <"$DEPENDENCIES_FILE"
fi

for result_file in "${CONTRACT_RESULTS[@]}"; do
  [[ -f "$result_file" ]] || fail "resultado de contrato não existe"
  grep -Fq '"schema": "wildfly-migration-contract-result/v1"' "$result_file" ||
    fail "schema do resultado de contrato divergente"
  grep -Fq "\"warSha256\": \"$WAR_SHA256\"" "$result_file" ||
    fail "resultado de contrato não corresponde ao WAR congelado"

  if grep -Fq '"profile": "ci-h2"' "$result_file"; then
    grep -Fq '"qualification": "portable-ci"' "$result_file" ||
      fail "resultado H2 sem classificação portable-ci"
  elif grep -Fq '"profile": "oracle"' "$result_file"; then
    grep -Fq '"qualification": "oracle-qualified"' "$result_file" ||
      fail "resultado Oracle sem classificação oracle-qualified"
  else
    fail "perfil desconhecido no resultado de contrato"
  fi

  while IFS=$'\t' read -r scenario expected _; do
    [[ "$scenario" == "scenario" ]] && continue
    grep -Fq "\"$scenario\": \"$expected\"" "$result_file" ||
      fail "resultado não preservou o cenário $scenario"
  done <"$SCENARIOS_FILE"

  RESULT_SCENARIO_COUNT="$(
    grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$result_file"
  )"
  [[ "$RESULT_SCENARIO_COUNT" == "$SCENARIO_COUNT" ]] ||
    fail "resultado contém cenário ausente ou adicional"
  if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$result_file"; then
    fail "resultado de contrato contém configuração sensível"
  fi
done

printf 'OK: baseline CP-1G — %s cenários, %s dependências, %s JARs no WAR' \
  "$SCENARIO_COUNT" "$DEPENDENCY_COUNT" "$PACKAGED_COUNT"
if [[ -n "$WAR_FILE" ]]; then
  printf ', SHA-256 %s' "$WAR_SHA256"
fi
printf '\n'
