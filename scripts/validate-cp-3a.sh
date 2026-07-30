#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/before-runtime.properties"
CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-before-ci-h2.json"
DOCUMENT="$REPOSITORY_ROOT/docs/evidence/CP-3A.md"
TASKS="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
SMOKE="$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh"
WAR_FILE=""
CONTRACT_RESULT_FILE=""
EXPECTED_SOURCE_COMMIT="0440337d2256581666994f3192bf6c3516ce590e"
EXPECTED_WAR_SHA256="62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2"

fail() {
  printf 'FALHA CP-3A/3.1: %s\n' "$1" >&2
  exit 1
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
      CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      printf 'Uso: ./scripts/validate-cp-3a.sh [--war ARQUIVO] [--contract-result ARQUIVO]\n'
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

for path in \
  "$EVIDENCE" \
  "$CONTRACT" \
  "$DOCUMENT" \
  "$TASKS" \
  "$SMOKE" \
  "$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/manifest.properties" \
  "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for property in \
  "source.commit=$EXPECTED_SOURCE_COMMIT" \
  "source.war.sha256=$EXPECTED_WAR_SHA256" \
  'source.bytecode.major=52' \
  'target.java=Eclipse-Temurin-OpenJDK-17.0.20+8' \
  'target.wildfly=WildFly-Community-26.1.3.Final' \
  'application.changed=false' \
  'pom.changed=false' \
  'dependencies.changed=false' \
  'war.changed=false' \
  'contract.scenarios=14' \
  'contract.result=passed' \
  'oracle.result=not-executed-in-activity-3.1' \
  'result=passed-without-application-correction'; do
  grep -Fxq "$property" "$EVIDENCE" ||
    fail "evidência não contém: $property"
done

for contract_marker in \
  '"qualification": "portable-ci"' \
  '"profile": "ci-h2"' \
  "\"sourceCommit\": \"$EXPECTED_SOURCE_COMMIT\"" \
  "\"warSha256\": \"$EXPECTED_WAR_SHA256\"" \
  '"runtime": "java17-wildfly26.1.3"'; do
  grep -Fq "$contract_marker" "$CONTRACT" ||
    fail "contrato versionado não contém: $contract_marker"
done

scenario_count="$(
  grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' "$CONTRACT"
)"
[[ "$scenario_count" == "14" ]] ||
  fail "contrato versionado não contém os 14 cenários"

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$EVIDENCE" "$CONTRACT" "$DOCUMENT"; then
  fail "evidência CP-3A contém configuração sensível"
fi

for smoke_marker in \
  '"$2" == "17"' \
  'runtime/portable-runtime-cache.sha256' \
  'RUNTIME_IDENTIFIER="java17-wildfly26.1.3"' \
  '--diagnostic-log'; do
  grep -Fq -- "$smoke_marker" "$SMOKE" ||
    fail "harness Java 17 não contém: $smoke_marker"
done

for document_marker in \
  'migration/02-java8-wildfly26' \
  'Nenhum fonte, POM, descritor, biblioteca ou byte do WAR foi alterado' \
  'portáteis passaram: saúde, listagem, criação' \
  'compatibilidade de recompilação com o JDK 17' \
  'qualificação Oracle permanece pendente'; do
  grep -Fq "$document_marker" "$DOCUMENT" ||
    fail "documentação da tentativa não contém: $document_marker"
done

grep -Fq -- \
  '- [x] 3.1 Materializar `migration/02-java8-wildfly26`' \
  "$TASKS" ||
  fail "atividade 3.1 ainda não está marcada como concluída"

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  actual_war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
  [[ "$actual_war_sha256" == "$EXPECTED_WAR_SHA256" ]] ||
    fail "WAR informado não corresponde ao artefato imutável da fase 2"
fi

if [[ -n "$CONTRACT_RESULT_FILE" ]]; then
  [[ -f "$CONTRACT_RESULT_FILE" ]] ||
    fail "resultado de contrato informado não existe"
  for runtime_marker in \
    "\"sourceCommit\": \"$EXPECTED_SOURCE_COMMIT\"" \
    "\"warSha256\": \"$EXPECTED_WAR_SHA256\"" \
    '"runtime": "java17-wildfly26.1.3"'; do
    grep -Fq "$runtime_marker" "$CONTRACT_RESULT_FILE" ||
      fail "resultado dinâmico não contém: $runtime_marker"
  done
fi

printf 'OK: CP-3A/3.1 comprova o WAR da fase 2 no Java 17 sem correção\n'
