#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_DIRECTORY="$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26"
PROPERTIES_FILE="$MANIFEST_DIRECTORY/manifest.properties"
COMPONENTS_FILE="$MANIFEST_DIRECTORY/components.tsv"
DEPENDENCIES_FILE="$MANIFEST_DIRECTORY/maven-dependencies.tsv"
LIMITATIONS_FILE="$MANIFEST_DIRECTORY/known-limitations.tsv"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
PHASE1_DEPENDENCIES="$REPOSITORY_ROOT/migration/baselines/01-legacy/maven-dependencies.tsv"
PHASE2_RUNTIME_MANIFEST="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv"
PORTABLE_RUNTIME_MANIFEST="$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
PHASE2_COMPARISON="$REPOSITORY_ROOT/migration/evidence/CP-2D/phase2-comparison.json"
WAR_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2d-manifest.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso: ./scripts/validate-cp-2d-manifest.sh [--war ARQUIVO]

Sem argumentos, valida o manifesto versionado da fase 2. Com --war, compara
também checksum, bytecode, árvore Maven e cada JAR de WEB-INF/lib.
USAGE
}

fail() {
  printf 'FALHA CP-2D manifesto: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2d-manifest.*)
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

  count="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { count++ } END { print count + 0 }' \
      "$PROPERTIES_FILE"
  )"
  [[ "$count" == "1" ]] ||
    fail "propriedade ausente ou duplicada: $key"
  value="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { sub(/^[^=]*=/, ""); print }' \
      "$PROPERTIES_FILE"
  )"
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
  "$MANIFEST_DIRECTORY/README.md" \
  "$PROPERTIES_FILE" \
  "$COMPONENTS_FILE" \
  "$DEPENDENCIES_FILE" \
  "$LIMITATIONS_FILE" \
  "$EXPECTED_LIBRARIES" \
  "$PHASE1_DEPENDENCIES" \
  "$PHASE2_RUNTIME_MANIFEST" \
  "$PORTABLE_RUNTIME_MANIFEST" \
  "$PHASE2_COMPARISON" \
  "$REPOSITORY_ROOT/docs/evidence/CP-2D.md" \
  "$REPOSITORY_ROOT/docs/h2-oracle-differences.md"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

[[ "$(property schema)" == "wildfly-migration-phase-manifest/v1" ]] ||
  fail "schema divergente"
[[ "$(property phase)" == "2" ]] || fail "fase divergente"
[[ "$(property checkpoint)" == "CP-2D" ]] ||
  fail "checkpoint divergente"
[[ "$(property tag)" == "migration/02-java8-wildfly26" ]] ||
  fail "tag pública reservada divergente"
[[ "$(property source.tag)" == "migration/01-legacy-baseline" ]] ||
  fail "tag de origem divergente"
[[ "$(property target.java)" == "Eclipse-Temurin-OpenJDK-8u492-b09" ]] ||
  fail "Java alvo divergente"
[[ "$(property target.maven)" == "Apache-Maven-3.9.16" ]] ||
  fail "Maven alvo divergente"
[[ "$(property target.wildfly)" == \
  "WildFly-Community-26.1.3.Final" ]] ||
  fail "WildFly alvo divergente"
[[ "$(property target.ee)" == "Jakarta-EE-Web-Profile-8.0" ]] ||
  fail "plataforma EE divergente"
[[ "$(property target.namespace)" == "javax" ]] ||
  fail "namespace da ponte divergente"
[[ "$(property target.oracle)" == "Oracle-Database-19c-RU-19.3" ]] ||
  fail "Oracle alvo divergente"
[[ "$(property qualification.portable-ci)" == \
  "passed-with-documented-limitations" ]] ||
  fail "estado portable-ci divergente"
[[ "$(property qualification.oracle-qualified)" == "passed" ]] ||
  fail "estado oracle-qualified divergente"

SOURCE_COMMIT="$(property evidence.sourceCommit)"
WAR_SHA256="$(property war.sha256)"
TREE_SHA256="$(property maven.tree.sha256)"
[[ "$SOURCE_COMMIT" =~ ^[0-9a-f]{40}$ ]] ||
  fail "commit-fonte inválido"
[[ "$WAR_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "checksum do WAR inválido"
[[ "$TREE_SHA256" =~ ^[0-9a-f]{64}$ ]] ||
  fail "checksum da árvore Maven inválido"

for marker in \
  '"schema": "wildfly-migration-phase2-comparison/v1"' \
  "\"sourceCommit\": \"$SOURCE_COMMIT\"" \
  "\"phase2WarSha256\": \"$WAR_SHA256\"" \
  '"scenarioCount": 14' \
  '"portableCi": "passed-with-documented-limitations"' \
  '"oracleQualified": "passed"' \
  '"result": "passed"'; do
  grep -Fq "$marker" "$PHASE2_COMPARISON" ||
    fail "comparação da fase 2 não contém: $marker"
done

[[ "$(head -n 1 "$COMPONENTS_FILE")" == \
  $'component\tversion\tusage\tartifact\tsha256\torigin\tlicense\tlifecycle\tprovenance' ]] ||
  fail "cabeçalho dos componentes divergente"
COMPONENT_COUNT="$(
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
    "$COMPONENTS_FILE"
)"
[[ "$COMPONENT_COUNT" == "$(property runtime.componentCount)" ]] ||
  fail "quantidade de componentes divergente"
if ! awk -F '\t' '
  NR > 1 {
    if (NF != 9 || seen[$1]++ ||
        $1 == "" || $2 == "" || $3 == "" || $4 == "" ||
        $5 == "" || $6 == "" || $7 == "" || $8 == "" || $9 == "") {
      exit 1
    }
    if ($4 == "external-instance") {
      if ($5 != "-") {
        exit 1
      }
    } else if ($5 !~ /^[0-9a-f]{64}$/) {
      exit 1
    }
    if ($4 != "external-instance" && $6 !~ /^https:\/\//) {
      exit 1
    }
  }
' "$COMPONENTS_FILE"; then
  fail "manifesto de componentes incompleto ou inválido"
fi

awk -F '\t' '
  NR > 1 {
    print $1 "\t" $2 "\t" $3 "\t" $6 "\t" $4 "\t" $5 "\t" $8
  }
' "$PHASE2_RUNTIME_MANIFEST" | LC_ALL=C sort \
  >"$TEMP_DIRECTORY/runtime-source.tsv"
awk -F '\t' '
  NR > 1 && $9 == "runtime/phase2/java8-wildfly26/runtime-manifest.tsv" {
    print $1 "\t" $2 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8
  }
' "$COMPONENTS_FILE" | LC_ALL=C sort \
  >"$TEMP_DIRECTORY/runtime-frozen.tsv"
if ! diff -u "$TEMP_DIRECTORY/runtime-source.tsv" \
    "$TEMP_DIRECTORY/runtime-frozen.tsv"; then
  fail "componentes Java, Maven ou WildFly divergem do manifesto do runtime"
fi

expected_h2="$(
  awk -F '\t' '
    NR > 1 && $1 == "h2" {
      print $1 "\t" $2 "\t" $3 "\t" $6 "\t" $4 "\t" $5 "\t" "EOL-test-only"
    }
  ' "$PORTABLE_RUNTIME_MANIFEST"
)"
actual_h2="$(
  awk -F '\t' '
    NR > 1 && $1 == "h2" {
      print $1 "\t" $2 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8
    }
  ' "$COMPONENTS_FILE"
)"
[[ -n "$expected_h2" && "$actual_h2" == "$expected_h2" ]] ||
  fail "componente H2 diverge da fonte portátil aprovada"

for component_marker in \
  $'ojdbc7\t12.1.0.2.0\toracle-qualified\tojdbc7.jar\t0d34cddb5726232ad4c0e5db731e930c9c75d8f74b9c4aa449799cc43dd3e829\t' \
  $'oracle-database\t19.3.0.0.0\toracle-qualified\texternal-instance\t-\t'; do
  grep -Fq "$component_marker" "$COMPONENTS_FILE" ||
    fail "componente oficial ausente: $component_marker"
done

[[ "$(head -n 1 "$DEPENDENCIES_FILE")" == \
  $'groupId\tartifactId\tversion\tscope\trelation\tpackaged\twarFile\tsha256\torigin\tlicense\tlicenseEvidence' ]] ||
  fail "cabeçalho das dependências divergente"
DEPENDENCY_COUNT="$(
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
    "$DEPENDENCIES_FILE"
)"
PROVIDED_COUNT="$(
  awk -F '\t' 'NR > 1 && $4 == "provided" { count++ } END { print count + 0 }' \
    "$DEPENDENCIES_FILE"
)"
PACKAGED_COUNT="$(
  awk -F '\t' 'NR > 1 && $6 == "true" { count++ } END { print count + 0 }' \
    "$DEPENDENCIES_FILE"
)"
[[ "$DEPENDENCY_COUNT" == "$(property maven.dependencyCount)" ]] ||
  fail "quantidade de dependências divergente"
[[ "$PROVIDED_COUNT" == "$(property maven.providedCount)" ]] ||
  fail "quantidade de dependências provided divergente"
[[ "$PACKAGED_COUNT" == "$(property maven.packagedCount)" ]] ||
  fail "quantidade de dependências empacotadas divergente"
[[ "$PACKAGED_COUNT" == "$(property war.libraryCount)" ]] ||
  fail "contagem do WAR e das dependências diverge"

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
  fail "inventário Maven incompleto ou inválido"
fi

expected_api_row=$'jakarta.platform\tjakarta.jakartaee-web-api\t8.0.0\tprovided\tdirect\tfalse\t-\t72a69e581e4cc84152d95aa0ae8af6907f3daaed488517bba9264e96cb5f9669\thttps://repo.maven.apache.org/maven2/jakarta/platform/jakarta.jakartaee-web-api/8.0.0/jakarta.jakartaee-web-api-8.0.0.jar\tEPL-2.0-OR-GPL-2.0-with-classpath-exception\tMETA-INF/LICENSE.txt e SPDX do POM'
grep -Fxq "$expected_api_row" "$DEPENDENCIES_FILE" ||
  fail "API Jakarta EE Web Profile 8 provided divergente"

awk -F '\t' 'NR > 1 && $4 == "compile"' "$PHASE1_DEPENDENCIES" |
  LC_ALL=C sort >"$TEMP_DIRECTORY/phase1-compile.tsv"
awk -F '\t' 'NR > 1 && $4 == "compile"' "$DEPENDENCIES_FILE" |
  LC_ALL=C sort >"$TEMP_DIRECTORY/phase2-compile.tsv"
if ! diff -u "$TEMP_DIRECTORY/phase1-compile.tsv" \
    "$TEMP_DIRECTORY/phase2-compile.tsv"; then
  fail "bibliotecas legadas mudaram no manifesto da fase 2"
fi

awk -F '\t' 'NR > 1 && $6 == "true" { print $7 }' \
  "$DEPENDENCIES_FILE" | LC_ALL=C sort \
  >"$TEMP_DIRECTORY/manifest-libraries.txt"
LC_ALL=C sort "$EXPECTED_LIBRARIES" \
  >"$TEMP_DIRECTORY/expected-libraries.txt"
if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/manifest-libraries.txt"; then
  fail "dependências empacotadas divergem da allowlist da fase 2"
fi

[[ "$(head -n 1 "$LIMITATIONS_FILE")" == \
  $'id\tarea\tcomponent\tstate\timpact\tdisposition\tevidence' ]] ||
  fail "cabeçalho das limitações divergente"
LIMITATION_COUNT="$(
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
    "$LIMITATIONS_FILE"
)"
[[ "$LIMITATION_COUNT" == "$(property limitations.count)" ]] ||
  fail "quantidade de limitações divergente"
if ! awk -F '\t' '
  NR > 1 {
    if (NF != 7 || $1 !~ /^P2-LIM-[0-9][0-9][0-9]$/ ||
        seen[$1]++ || $2 == "" || $3 == "" || $4 == "" ||
        $5 == "" || $6 == "" || $7 !~ /^[A-Za-z0-9._\/-]+$/) {
      exit 1
    }
  }
' "$LIMITATIONS_FILE"; then
  fail "catálogo de limitações incompleto, duplicado ou inválido"
fi
while IFS=$'\t' read -r id _ _ _ _ _ evidence; do
  [[ "$id" == "id" ]] && continue
  [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
    fail "evidência da limitação não existe: $evidence"
done <"$LIMITATIONS_FILE"

for limitation_marker in \
  'WildFly-26.1.3.Final' \
  'H2-1.4.200' \
  'ojdbc7-12.1.0.2.0' \
  'Log4j-1.2.14' \
  'Apache-Tiles-2.1.4' \
  'Commons-FileUpload-1.2.2' \
  'Reflections-0.9.10' \
  'XMLBeans-2.3.0-dom4j-1.6.1-and-duplicated-XML-APIs' \
  'MyBatis-3.4.5' \
  'Oracle-Home-one-off-patches' \
  'upload-size-metadata'; do
  grep -Fq "$limitation_marker" "$LIMITATIONS_FILE" ||
    fail "limitação conhecida ausente: $limitation_marker"
done

for documentation_marker in \
  '# Manifesto da fase 2 — Java 8 e WildFly 26' \
  'migration/02-java8-wildfly26' \
  'atividade 2.20' \
  "$SOURCE_COMMIT" \
  '20' \
  'portable-ci' \
  'oracle-qualified'; do
  grep -Fq "$documentation_marker" "$MANIFEST_DIRECTORY/README.md" ||
    fail "README do manifesto não contém: $documentation_marker"
done

if grep -R -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$MANIFEST_DIRECTORY"; then
  fail "manifesto da fase 2 contém configuração sensível"
fi

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  [[ "$(sha256sum "$WAR_FILE" | awk '{print $1}')" == "$WAR_SHA256" ]] ||
    fail "WAR construído diverge do checksum do manifesto"

  TREE_PATH="$REPOSITORY_ROOT/$(property maven.tree.path)"
  [[ -f "$TREE_PATH" ]] || fail "árvore Maven gerada não existe"
  [[ "$(sha256sum "$TREE_PATH" | awk '{print $1}')" == "$TREE_SHA256" ]] ||
    fail "árvore Maven gerada diverge do manifesto"

  awk -F '\t' 'NR > 1 { print $1 "\t" $2 "\t" $3 "\t" $4 }' \
    "$DEPENDENCIES_FILE" | LC_ALL=C sort \
    >"$TEMP_DIRECTORY/manifest-tree.tsv"
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
  ' "$TREE_PATH" | LC_ALL=C sort \
    >"$TEMP_DIRECTORY/generated-tree.tsv"
  if ! diff -u "$TEMP_DIRECTORY/manifest-tree.tsv" \
      "$TEMP_DIRECTORY/generated-tree.tsv"; then
    fail "coordenadas da árvore Maven divergem do manifesto"
  fi

  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"
  awk '
    /^WEB-INF\/lib\/[^/]+\.jar$/ {
      sub(/^WEB-INF\/lib\//, "")
      print
    }
  ' "$TEMP_DIRECTORY/war-entries.txt" | LC_ALL=C sort \
    >"$TEMP_DIRECTORY/actual-libraries.txt"
  if ! diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
      "$TEMP_DIRECTORY/actual-libraries.txt"; then
    fail "WEB-INF/lib real diverge do manifesto"
  fi

  unzip -p "$WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class \
    >"$TEMP_DIRECTORY/LegacyBuildMarker.class"
  javap -verbose "$TEMP_DIRECTORY/LegacyBuildMarker.class" |
    grep -Fq "major version: $(property war.bytecode.major)" ||
    fail "WAR não contém bytecode Java 8 major 52"

  unzip -qq "$WAR_FILE" 'WEB-INF/lib/*.jar' \
    -d "$TEMP_DIRECTORY/extracted"
  while IFS=$'\t' read -r _ _ _ _ _ packaged war_file expected_sha _; do
    [[ "$packaged" == "packaged" || "$packaged" == "false" ]] && continue
    actual_sha="$(
      sha256sum "$TEMP_DIRECTORY/extracted/WEB-INF/lib/$war_file" |
        awk '{print $1}'
    )"
    [[ "$actual_sha" == "$expected_sha" ]] ||
      fail "checksum do JAR empacotado diverge: $war_file"
  done <"$DEPENDENCIES_FILE"

  "$REPOSITORY_ROOT/scripts/validate-cp-2c.sh" --war "$WAR_FILE"
fi

printf 'OK: manifesto da fase 2 — %s componentes, %s dependências, %s JARs e %s limitações' \
  "$COMPONENT_COUNT" "$DEPENDENCY_COUNT" "$PACKAGED_COUNT" "$LIMITATION_COUNT"
if [[ -n "$WAR_FILE" ]]; then
  printf ', SHA-256 %s' "$WAR_SHA256"
fi
printf '\n'
