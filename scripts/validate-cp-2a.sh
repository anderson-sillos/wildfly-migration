#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly9/runtime-manifest.tsv"
BASELINE="$REPOSITORY_ROOT/migration/baselines/01-legacy/baseline.properties"
SCENARIOS="$REPOSITORY_ROOT/migration/baselines/01-legacy/contract-scenarios.tsv"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt"
WAR_FILE=""
CONTRACT_RESULTS=()
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2a.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-2a.sh \
    [--war ARQUIVO] [--contract-result ARQUIVO]...

Sem argumentos, valida manifesto, documentação e evidências estruturadas.
Com --war, valida bytecode Java 8 e o conteúdo preservado de WEB-INF/lib.
USAGE
}

fail() {
  printf 'FALHA CP-2A: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2a.*)
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

for path in \
  "$MANIFEST" \
  "$BASELINE" \
  "$SCENARIOS" \
  "$EXPECTED_LIBRARIES" \
  "$REPOSITORY_ROOT/docs/cp-2a-java8-wildfly9.md" \
  "$REPOSITORY_ROOT/docs/evidence/CP-2A.md" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/before-runtime.properties" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/before-build.properties" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/after.properties" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/contract-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/contract-oracle.json" \
  "$REPOSITORY_ROOT/migration/steps/CP-2A-java8-toolchain.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-2A-wildfly9-max-perm-size.md"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

grep -Fxq 'war.bytecode.major=52' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/after.properties" ||
  fail "evidência depois da correção não registra bytecode major 52"
grep -Fxq 'maven.tree.sha256=2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/after.properties" ||
  fail "árvore Maven deixou de corresponder ao baseline"
grep -Fxq 'portable-ci.result=passed' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/after.properties" ||
  fail "evidência H2 depois da correção não está aprovada"
grep -Fxq 'oracle-qualified.result=passed' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/after.properties" ||
  fail "evidência Oracle depois da correção não está aprovada"

for evidence_contract in contract-ci-h2.json contract-oracle.json; do
  evidence_path="$REPOSITORY_ROOT/migration/evidence/CP-2A/$evidence_contract"
  grep -Fq '"commit": "c76f42f4035ac08b13fca478f1d8e375190761b9"' \
    "$evidence_path" ||
    fail "contrato rastreado não aponta para o commit de implementação"
  grep -Fq '"warSha256": "bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4"' \
    "$evidence_path" ||
    fail "contrato rastreado não aponta para o WAR aprovado"
  grep -Fq '"runtime": "java8-wildfly9.0.2"' "$evidence_path" ||
    fail "contrato rastreado não identifica o runtime CP-2A"
  if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$evidence_path"; then
    fail "contrato rastreado contém configuração sensível"
  fi
  evidence_scenario_count="$(
    grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$evidence_path"
  )"
  [[ "$evidence_scenario_count" == "14" ]] ||
    fail "contrato rastreado não contém os 14 cenários"
done
grep -Fq '"qualification": "portable-ci"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/contract-ci-h2.json" ||
  fail "contrato H2 rastreado perdeu a classificação portable-ci"
grep -Fq '"qualification": "oracle-qualified"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2A/contract-oracle.json" ||
  fail "contrato Oracle rastreado perdeu a qualificação"

[[ "$(head -n 1 "$MANIFEST")" == \
  $'component\tversion\tarchive\torigin\tlicense\tsha256\tlifecycle\tscope' ]] ||
  fail "cabeçalho do manifesto Java 8 divergente"

expected_java_row=$'temurin-openjdk\t8u492-b09\tOpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz\thttps://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz\tGPL-2.0-only WITH Classpath-exception-2.0\tda257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e\tmaintained-by-Eclipse-Temurin\tCP-2A-and-CP-2B'
[[ "$(sed -n '2p' "$MANIFEST")" == "$expected_java_row" ]] ||
  fail "registro Temurin 8u492 não corresponde à versão fixada"
[[ "$(wc -l <"$MANIFEST" | tr -d ' ')" == "2" ]] ||
  fail "manifesto Java 8 deve conter exatamente um componente"

for pair in \
  'before-runtime.properties:result=passed' \
  'before-runtime.properties:source.bytecode.major=51' \
  'before-runtime.properties:warning.category=removed-jvm-option' \
  'before-build.properties:result=expected-failure' \
  'before-build.properties:stage=compilation' \
  'before-build.properties:exit.code=1'; do
  evidence_file="${pair%%:*}"
  marker="${pair#*:}"
  grep -Fxq "$marker" \
    "$REPOSITORY_ROOT/migration/evidence/CP-2A/$evidence_file" ||
    fail "evidência antes da correção não contém $marker"
done

grep -Fq $'INC-005\tCP-2A\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-005 não foi catalogada"
grep -Fq $'INC-006\tCP-2A\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-006 não foi catalogada"
for phase2_marker in \
  'target.java=Eclipse-Temurin-OpenJDK-8u492-b09' \
  'war.bytecode.major=52' \
  'tag=migration/02-java8-wildfly26'; do
  grep -Fxq "$phase2_marker" \
    "$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/manifest.properties" ||
    fail "manifesto imutável não preserva o contrato Java 8: $phase2_marker"
done
grep -Fq -- '--java 8' "$REPOSITORY_ROOT/docs/cp-2a-java8-wildfly9.md" ||
  fail "runbook não seleciona Java 8 explicitamente"
grep -Fq 'Conclusão comprovada' \
  "$REPOSITORY_ROOT/docs/evidence/CP-2A.md" ||
  fail "evidência CP-2A não contém a conclusão explicativa"
for conclusion_marker in \
  'Compatibilidade binária inicial' \
  'Recompilação real para Java 8' \
  'Configuração do runtime' \
  'Equivalência funcional' \
  'Qualificação da persistência' \
  'Isolamento da mudança' \
  'Síntese' \
  'Limites da conclusão'; do
  grep -Fq "$conclusion_marker" \
    "$REPOSITORY_ROOT/docs/evidence/CP-2A.md" ||
    fail "conclusão CP-2A não contém: $conclusion_marker"
done
grep -Fq 'MaxPermSize' \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
  fail "smoke não contém a regressão da opção removida"

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"
  unzip -p "$WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class \
    >"$TEMP_DIRECTORY/LegacyBuildMarker.class"
  javap -verbose "$TEMP_DIRECTORY/LegacyBuildMarker.class" |
    grep -Fq 'major version: 52' ||
    fail "WAR não contém bytecode Java 8 major 52"

  awk '
    /^WEB-INF\/lib\/[^/]+\.jar$/ {
      sub(/^WEB-INF\/lib\//, "")
      print
    }
  ' "$TEMP_DIRECTORY/war-entries.txt" |
    LC_ALL=C sort >"$TEMP_DIRECTORY/actual-libraries.txt"
  LC_ALL=C sort "$EXPECTED_LIBRARIES" >"$TEMP_DIRECTORY/expected-libraries.txt"
  diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt" ||
    fail "WEB-INF/lib mudou durante a troca isolada para Java 8"
  WAR_SHA256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
fi

scenario_count="$(
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' "$SCENARIOS"
)"
for result_file in "${CONTRACT_RESULTS[@]}"; do
  [[ -n "$WAR_FILE" ]] ||
    fail "--contract-result exige também --war para vincular o artefato"
  [[ -f "$result_file" ]] || fail "resultado de contrato não existe"
  grep -Fq '"schema": "wildfly-migration-contract-result/v1"' "$result_file" ||
    fail "schema do resultado de contrato divergente"
  grep -Fq "\"warSha256\": \"$WAR_SHA256\"" "$result_file" ||
    fail "resultado de contrato não corresponde ao WAR informado"
  grep -Fq '"runtime": "java8-wildfly9.0.2"' "$result_file" ||
    fail "resultado não identifica Java 8/WildFly 9"

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
  done <"$SCENARIOS"
  actual_scenarios="$(
    grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$result_file"
  )"
  [[ "$actual_scenarios" == "$scenario_count" ]] ||
    fail "quantidade de cenários do contrato diverge do baseline"
done

printf 'OK: CP-2A preserva dependências e contratos no Java 8/WildFly 9'
if [[ -n "$WAR_FILE" ]]; then
  printf ', WAR SHA-256 %s' "$WAR_SHA256"
fi
printf '\n'
