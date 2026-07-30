#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BEFORE_RUNTIME_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/before-runtime.properties"
BEFORE_BUILD_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/before-build.properties"
AFTER_BUILD_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/after-build.properties"
BEFORE_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-before-ci-h2.json"
AFTER_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-after-ci-h2.json"
DOCUMENT="$REPOSITORY_ROOT/docs/evidence/CP-3A.md"
TASKS="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
SMOKE="$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh"
BUILD="$REPOSITORY_ROOT/scripts/build-cp-1d.sh"
BUILD_WRAPPER="$REPOSITORY_ROOT/scripts/build-cp-3a.sh"
AUDIT="$REPOSITORY_ROOT/scripts/audit-legacy-war.sh"
CATALOG="$REPOSITORY_ROOT/migration/incompatibilities.tsv"
WAR_FILE=""
CONTRACT_RESULT_FILE=""
AFTER_WAR_FILE=""
AFTER_CONTRACT_RESULT_FILE=""
EXPECTED_SOURCE_COMMIT="0440337d2256581666994f3192bf6c3516ce590e"
EXPECTED_WAR_SHA256="62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2"
EXPECTED_IMPLEMENTATION_COMMIT="fa87f1d8f6c74e1be1f7d978ada04ea743b7e551"
EXPECTED_AFTER_WAR_SHA256="afc4d98594c3cf7113018f78fab4e4be6b7c0202bbe5cbd9b5e1db8390cbc294"

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
    --after-war)
      [[ $# -ge 2 ]] || fail "--after-war exige um arquivo"
      AFTER_WAR_FILE="$2"
      shift 2
      ;;
    --after-contract-result)
      [[ $# -ge 2 ]] || fail "--after-contract-result exige um arquivo"
      AFTER_CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      printf '%s\n' \
        'Uso: ./scripts/validate-cp-3a.sh [--war ARQUIVO] [--contract-result ARQUIVO]' \
        '  [--after-war ARQUIVO] [--after-contract-result ARQUIVO]'
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

for path in \
  "$BEFORE_RUNTIME_EVIDENCE" \
  "$BEFORE_BUILD_EVIDENCE" \
  "$AFTER_BUILD_EVIDENCE" \
  "$BEFORE_CONTRACT" \
  "$AFTER_CONTRACT" \
  "$DOCUMENT" \
  "$TASKS" \
  "$SMOKE" \
  "$BUILD" \
  "$BUILD_WRAPPER" \
  "$AUDIT" \
  "$CATALOG" \
  "$REPOSITORY_ROOT/migration/steps/CP-3A-java17-toolchain.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-3A-java17-bytecode-audit.md" \
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
  grep -Fxq "$property" "$BEFORE_RUNTIME_EVIDENCE" ||
    fail "evidência não contém: $property"
done

for contract_marker in \
  '"qualification": "portable-ci"' \
  '"profile": "ci-h2"' \
  "\"sourceCommit\": \"$EXPECTED_SOURCE_COMMIT\"" \
  "\"warSha256\": \"$EXPECTED_WAR_SHA256\"" \
  '"runtime": "java17-wildfly26.1.3"'; do
  grep -Fq "$contract_marker" "$BEFORE_CONTRACT" ||
    fail "contrato versionado não contém: $contract_marker"
done

scenario_count="$(
  grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
    "$BEFORE_CONTRACT"
)"
[[ "$scenario_count" == "14" ]] ||
  fail "contrato versionado não contém os 14 cenários"

for property in \
  "implementation.commit=$EXPECTED_IMPLEMENTATION_COMMIT" \
  'java.version=17.0.20+8' \
  'maven.version=3.9.16' \
  'wildfly.version=26.1.3.Final' \
  'toolchain.selection=wrapper-command-line-properties' \
  'application.changed=false' \
  'pom.changed=false' \
  'dependencies.changed=false' \
  "war.sha256=$EXPECTED_AFTER_WAR_SHA256" \
  'war.bytecode.major=61' \
  'war.libraryCount=20' \
  'maven.dependencyCount=21' \
  'maven.tree.sha256=8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca' \
  'portable-ci.contract.scenarios=14' \
  'portable-ci.result=passed' \
  'oracle-qualified.result=not-executed-in-activity-3.2' \
  'result=passed-with-harness-only-corrections'; do
  grep -Fxq "$property" "$AFTER_BUILD_EVIDENCE" ||
    fail "evidência após recompilação não contém: $property"
done

for property in \
  'result=expected-failure' \
  'exit.code=1' \
  'category=toolchain-policy' \
  'signature=Detected-JDK-Version-17.0.20-is-not-in-the-allowed-range-1.8-1.9' \
  'cause=maven-enforcer-rejects-java17-before-compilation'; do
  grep -Fxq "$property" "$BEFORE_BUILD_EVIDENCE" ||
    fail "evidência da falha de build não contém: $property"
done

for contract_marker in \
  '"qualification": "portable-ci"' \
  '"profile": "ci-h2"' \
  "\"commit\": \"$EXPECTED_IMPLEMENTATION_COMMIT\"" \
  "\"sourceCommit\": \"$EXPECTED_IMPLEMENTATION_COMMIT\"" \
  "\"warSha256\": \"$EXPECTED_AFTER_WAR_SHA256\"" \
  '"runtime": "java17-wildfly26.1.3"'; do
  grep -Fq "$contract_marker" "$AFTER_CONTRACT" ||
    fail "contrato após recompilação não contém: $contract_marker"
done

scenario_count="$(
  grep -Ec '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
    "$AFTER_CONTRACT"
)"
[[ "$scenario_count" == "14" ]] ||
  fail "contrato após recompilação não contém os 14 cenários"

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$BEFORE_RUNTIME_EVIDENCE" "$BEFORE_BUILD_EVIDENCE" \
    "$AFTER_BUILD_EVIDENCE" "$BEFORE_CONTRACT" "$AFTER_CONTRACT" \
    "$DOCUMENT"; then
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

for build_marker in \
  '"$2" == "17"' \
  "'-Dphase2.java.version.range=[17,18)'" \
  "'-Dmaven.compiler.source=17'" \
  "'-Dmaven.compiler.target=17'" \
  '17) printf 61'; do
  grep -Fq -- "$build_marker" "$BUILD" ||
    fail "build Java 17 não contém: $build_marker"
done
grep -Fq -- '--java 17 --maven 3.9.16' "$BUILD_WRAPPER" ||
  fail "wrapper CP-3A não fixa Java 17 e Maven 3.9.16"
grep -Fq '"$2" != "61"' "$AUDIT" ||
  fail "auditoria não reconhece bytecode Java 17 major 61"

for catalog_marker in \
  $'INC-011\tCP-3A\t' \
  $'INC-012\tCP-3A\t'; do
  grep -Fq "$catalog_marker" "$CATALOG" ||
    fail "incompatibilidade não catalogada: ${catalog_marker%%$'\t'*}"
done

for document_marker in \
  'migration/02-java8-wildfly26' \
  'Nenhum arquivo-fonte, POM, descritor, biblioteca ou byte do WAR foi alterado' \
  'portáteis passaram: saúde, listagem, criação' \
  'compatibilidade de recompilação com o JDK 17' \
  'qualificação Oracle permanece pendente' \
  'Recompilação no Java 17 — atividade 3.2' \
  'bytecode major `61`' \
  'nenhuma correção de código ou' \
  'troca de biblioteca foi necessária' \
  'POM permanece Java 8 por padrão'; do
  grep -Fq "$document_marker" "$DOCUMENT" ||
    fail "documentação da tentativa não contém: $document_marker"
done

grep -Fq -- \
  '- [x] 3.1 Materializar `migration/02-java8-wildfly26`' \
  "$TASKS" ||
  fail "atividade 3.1 ainda não está marcada como concluída"
grep -Fq -- \
  '- [x] 3.2 Capturar e corrigir somente incompatibilidades necessárias' \
  "$TASKS" ||
  fail "atividade 3.2 ainda não está marcada como concluída"

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

if [[ -n "$AFTER_WAR_FILE" ]]; then
  [[ -f "$AFTER_WAR_FILE" ]] || fail "WAR após recompilação não existe"
  actual_after_war_sha256="$(
    sha256sum "$AFTER_WAR_FILE" | awk '{print $1}'
  )"
  [[ "$actual_after_war_sha256" == "$EXPECTED_AFTER_WAR_SHA256" ]] ||
    fail "WAR após recompilação diverge da evidência da atividade 3.2"
fi

if [[ -n "$AFTER_CONTRACT_RESULT_FILE" ]]; then
  [[ -n "$AFTER_WAR_FILE" ]] ||
    fail "--after-contract-result exige também --after-war"
  [[ -f "$AFTER_CONTRACT_RESULT_FILE" ]] ||
    fail "resultado após recompilação não existe"
  for runtime_marker in \
    "\"commit\": \"$EXPECTED_IMPLEMENTATION_COMMIT\"" \
    "\"sourceCommit\": \"$EXPECTED_IMPLEMENTATION_COMMIT\"" \
    "\"warSha256\": \"$EXPECTED_AFTER_WAR_SHA256\"" \
    '"runtime": "java17-wildfly26.1.3"'; do
    grep -Fq "$runtime_marker" "$AFTER_CONTRACT_RESULT_FILE" ||
      fail "resultado dinâmico após recompilação não contém: $runtime_marker"
  done
fi

printf 'OK: CP-3A/3.1 comprova o WAR da fase 2 no Java 17 sem correção\n'
printf 'OK: CP-3A/3.2 recompila no Java 17 com correções somente no harness\n'
