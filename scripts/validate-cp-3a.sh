#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BEFORE_RUNTIME_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/before-runtime.properties"
BEFORE_BUILD_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/before-build.properties"
AFTER_BUILD_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/after-build.properties"
BEFORE_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-before-ci-h2.json"
AFTER_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-after-ci-h2.json"
CLOSURE_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/closure.properties"
CLOSURE_PORTABLE_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-ci-h2.json"
CLOSURE_ORACLE_CONTRACT="$REPOSITORY_ROOT/migration/evidence/CP-3A/contract-oracle.json"
CLOSURE_ORACLE_STATE="$REPOSITORY_ROOT/migration/evidence/CP-3A/oracle-state.json"
CLOSURE_ORACLE_PERSISTENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/oracle-persistence.json"
ROLLBACK_EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-3A/rollback.properties"
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
PROMOTED_WAR_FILE=""
PROMOTED_CONTRACT_RESULT_FILE=""
ORACLE_CONTRACT_RESULT_FILE=""
ORACLE_STATE_RESULT_FILE=""
ORACLE_PERSISTENCE_RESULT_FILE=""
EXPECTED_SOURCE_COMMIT="0440337d2256581666994f3192bf6c3516ce590e"
EXPECTED_WAR_SHA256="62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2"
EXPECTED_IMPLEMENTATION_COMMIT="fa87f1d8f6c74e1be1f7d978ada04ea743b7e551"
EXPECTED_AFTER_WAR_SHA256="afc4d98594c3cf7113018f78fab4e4be6b7c0202bbe5cbd9b5e1db8390cbc294"
EXPECTED_CLOSURE_COMMIT="737feb6f4d08aca24a580d5421af4437b1b45b15"
EXPECTED_CLOSURE_WAR_SHA256="9206fd3b66ed00cd01bade70f2594102ec3b75d1d817ed317d6fabaca9459704"

fail() {
  printf 'FALHA CP-3A: %s\n' "$1" >&2
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
    --promoted-war)
      [[ $# -ge 2 ]] || fail "--promoted-war exige um arquivo"
      PROMOTED_WAR_FILE="$2"
      shift 2
      ;;
    --promoted-contract-result)
      [[ $# -ge 2 ]] ||
        fail "--promoted-contract-result exige um arquivo"
      PROMOTED_CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-contract-result)
      [[ $# -ge 2 ]] || fail "--oracle-contract-result exige um arquivo"
      ORACLE_CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-state-result)
      [[ $# -ge 2 ]] || fail "--oracle-state-result exige um arquivo"
      ORACLE_STATE_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-persistence-result)
      [[ $# -ge 2 ]] ||
        fail "--oracle-persistence-result exige um arquivo"
      ORACLE_PERSISTENCE_RESULT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      printf '%s\n' \
        'Uso: ./scripts/validate-cp-3a.sh [--war ARQUIVO] [--contract-result ARQUIVO]' \
        '  [--after-war ARQUIVO] [--after-contract-result ARQUIVO]' \
        '  [--promoted-war ARQUIVO --promoted-contract-result ARQUIVO]' \
        '  [--oracle-contract-result ARQUIVO --oracle-state-result ARQUIVO]' \
        '  [--oracle-persistence-result ARQUIVO]'
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
  "$CLOSURE_EVIDENCE" \
  "$CLOSURE_PORTABLE_CONTRACT" \
  "$CLOSURE_ORACLE_CONTRACT" \
  "$CLOSURE_ORACLE_STATE" \
  "$CLOSURE_ORACLE_PERSISTENCE" \
  "$ROLLBACK_EVIDENCE" \
  "$DOCUMENT" \
  "$TASKS" \
  "$SMOKE" \
  "$BUILD" \
  "$BUILD_WRAPPER" \
  "$AUDIT" \
  "$CATALOG" \
  "$REPOSITORY_ROOT/migration/steps/CP-3A-java17-toolchain.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-3A-h2-2-check-constraint.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-3A-java17-bytecode-audit.md" \
  "$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/manifest.properties" \
  "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256" \
  "$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/README.md" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/runtime-manifest.tsv" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/h2/module.xml" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/ci-h2.cli" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/oracle.cli" \
  "$REPOSITORY_ROOT/scripts/smoke-cp-3a-datasource.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-3a-h2.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-3a-oracle.sh" \
  "$REPOSITORY_ROOT/docs/cp-3a-java17-runtime.md"; do
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

for property in \
  'schema=wildfly-migration-cp3a-closure/v1' \
  "tested.commit=$EXPECTED_CLOSURE_COMMIT" \
  "war.sha256=$EXPECTED_CLOSURE_WAR_SHA256" \
  'war.bytecode.major=61' \
  'war.libraryCount=20' \
  'maven.tree.sha256=8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca' \
  'java.version=17.0.20+8' \
  'maven.version=3.9.16' \
  'wildfly.version=26.1.3.Final' \
  'h2.version=2.4.240' \
  'portable-ci.contract.scenarios=14' \
  'portable-ci.result=passed' \
  'oracle.database.version=19.3.0.0.0' \
  'oracle.jdbc=ojdbc7-12.1.0.2.0' \
  'oracle-qualified.contract.scenarios=14' \
  'oracle-qualified.state=passed' \
  'oracle-qualified.mybatisCommit=passed' \
  'oracle-qualified.mybatisRollback=passed' \
  'oracle-qualified.timestampRoundTrip=passed' \
  'oracle-qualified.blobRoundTrip=passed' \
  'oracle-qualified.result=passed' \
  'transient.oracle.data.cleanup=passed' \
  'result=passed'; do
  grep -Fxq "$property" "$CLOSURE_EVIDENCE" ||
    fail "evidência de fechamento não contém: $property"
done

for marker in \
  '"qualification": "portable-ci"' \
  '"profile": "ci-h2"' \
  "\"commit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
  "\"sourceCommit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
  "\"warSha256\": \"$EXPECTED_CLOSURE_WAR_SHA256\"" \
  '"runtime": "java17-wildfly26.1.3"'; do
  grep -Fq "$marker" "$CLOSURE_PORTABLE_CONTRACT" ||
    fail "contrato H2 do fechamento não contém: $marker"
done

for marker in \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  "\"commit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
  "\"sourceCommit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
  "\"warSha256\": \"$EXPECTED_CLOSURE_WAR_SHA256\""; do
  grep -Fq "$marker" "$CLOSURE_ORACLE_CONTRACT" ||
    fail "contrato Oracle do fechamento não contém: $marker"
done

for closure_contract in \
  "$CLOSURE_PORTABLE_CONTRACT" \
  "$CLOSURE_ORACLE_CONTRACT"; do
  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$closure_contract")" == "14" ]] ||
    fail "contrato do fechamento não contém os 14 cenários"
done

for result_file in \
  "$CLOSURE_ORACLE_STATE" \
  "$CLOSURE_ORACLE_PERSISTENCE"; do
  for marker in \
    '"qualification": "oracle-qualified"' \
    '"profile": "oracle"' \
    "\"commit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
    "\"sourceCommit\": \"$EXPECTED_CLOSURE_COMMIT\"" \
    "\"warSha256\": \"$EXPECTED_CLOSURE_WAR_SHA256\"" \
    '"runtime": "java17-wildfly26.1.3-ee8"' \
    '"databaseVersion": "19.3.0.0.0"' \
    '"jdbcDriver": "ojdbc7-12.1.0.2.0"'; do
    grep -Fq "$marker" "$result_file" ||
      fail "evidência Oracle do fechamento não contém: $marker"
  done
done
for marker in \
  '"schemaObjects": "passed"' \
  '"seedState": "passed"' \
  '"contractCreate": "passed"' \
  '"contractUploadBlob": "passed"' \
  '"contractXml": "passed"' \
  '"rejectedState": "passed"'; do
  grep -Fq "$marker" "$CLOSURE_ORACLE_STATE" ||
    fail "estado Oracle do fechamento não contém: $marker"
done
for marker in \
  '"mybatisCommit": "passed"' \
  '"mybatisRollback": "passed"' \
  '"timestampRoundTrip": "passed"' \
  '"blobRoundTrip": "passed"' \
  '"transientDataCleanup": "passed"'; do
  grep -Fq "$marker" "$CLOSURE_ORACLE_PERSISTENCE" ||
    fail "persistência Oracle do fechamento não contém: $marker"
done

for property in \
  'schema=wildfly-migration-cp3a-rollback/v1' \
  'source.tag=migration/02-java8-wildfly26' \
  "source.commit=$EXPECTED_SOURCE_COMMIT" \
  "source.war.sha256=$EXPECTED_WAR_SHA256" \
  'source.war.bytecode.major=52' \
  'source.maven.tree.sha256=8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca' \
  'worktree.clean.before=passed' \
  'build.result=passed' \
  'audit.result=passed' \
  'worktree.clean.after=passed' \
  'worktree.cleanup=passed' \
  'oracle.schema.changed=false' \
  'result=passed'; do
  grep -Fxq "$property" "$ROLLBACK_EVIDENCE" ||
    fail "evidência de rollback não contém: $property"
done

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$BEFORE_RUNTIME_EVIDENCE" "$BEFORE_BUILD_EVIDENCE" \
    "$AFTER_BUILD_EVIDENCE" "$BEFORE_CONTRACT" "$AFTER_CONTRACT" \
    "$CLOSURE_EVIDENCE" "$CLOSURE_PORTABLE_CONTRACT" \
    "$CLOSURE_ORACLE_CONTRACT" "$CLOSURE_ORACLE_STATE" \
    "$CLOSURE_ORACLE_PERSISTENCE" "$ROLLBACK_EVIDENCE" \
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
  '17) printf 61'; do
  grep -Fq -- "$build_marker" "$BUILD" ||
    fail "build Java 17 não contém: $build_marker"
done
grep -Fq -- '--java 17 --maven 3.9.16' "$BUILD_WRAPPER" ||
  fail "wrapper CP-3A não fixa Java 17 e Maven 3.9.16"
grep -Fq '"$2" != "61"' "$AUDIT" ||
  fail "auditoria não reconhece bytecode Java 17 major 61"

for pom_marker in \
  '<maven.compiler.source>17</maven.compiler.source>' \
  '<maven.compiler.target>17</maven.compiler.target>' \
  '<java.version.range>[17,18)</java.version.range>' \
  '<version>${java.version.range}</version>' \
  '<id>enforce-java17-toolchain</id>'; do
  grep -Fq "$pom_marker" "$REPOSITORY_ROOT/app/pom.xml" ||
    fail "POM ainda não promove Java 17: $pom_marker"
done
if grep -Fq 'phase2.java.version.range' "$REPOSITORY_ROOT/app/pom.xml"; then
  fail "POM ativo ainda depende da sobrescrita temporária da fase 2"
fi
for obsolete_override in \
  'Dphase2.java.version.range' \
  'Dmaven.compiler.source=17' \
  'Dmaven.compiler.target=17'; do
  if grep -Fq "$obsolete_override" "$BUILD"; then
    fail "build CP-3A ainda usa sobrescrita temporária: $obsolete_override"
  fi
done

expected_h2_row=$'h2\t2.4.240\th2-2.4.240.jar\thttps://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/h2-2.4.240.jar\tMPL-2.0 OR EPL-1.0\t29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0\tcomputed-from-fixed-origin\tmaintained-latest-release\tCP-3A-portable-ci'
grep -Fxq "$expected_h2_row" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/runtime-manifest.tsv" ||
  fail "manifesto CP-3A não fixa origem, licença e checksum do H2 2.4.240"
for cache_row in \
  '3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6  h2-1.4.200.jar' \
  '29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0  h2-2.4.240.jar'; do
  grep -Fxq "$cache_row" \
    "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256" ||
    fail "cache único não preserva a identidade H2: $cache_row"
done
grep -Fq \
  $'h2-2.4.240.jar\thttps://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/h2-2.4.240.jar' \
  "$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv" ||
  fail "origem H2 2.4.240 ausente do índice do cache"
for h2_marker in \
  'name="com.h2database.h2.cp3a"' \
  'path="h2-2.4.240.jar"'; do
  grep -Fq "$h2_marker" \
    "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/h2/module.xml" ||
    fail "módulo H2 CP-3A não contém: $h2_marker"
done
for status_marker in \
  'CASE STATUS' \
  "WHEN 'NOVO' THEN TRUE" \
  "WHEN 'APROVADO' THEN TRUE" \
  "WHEN 'CANCELADO' THEN TRUE"; do
  grep -Fq "$status_marker" \
    "$REPOSITORY_ROOT/app/src/main/resources/db/h2/001_schema.sql" ||
    fail "correção INC-013 ausente do schema H2: $status_marker"
done
for profile_marker in \
  'jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1' \
  'driver-module-name=com.h2database.h2.cp3a' \
  'jndi-name=java:/jdbc/MigrationDS'; do
  grep -Fq "$profile_marker" \
    "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/ci-h2.cli" ||
    fail "perfil H2 CP-3A não contém: $profile_marker"
done
if grep -Eiq \
    'jdbc:h2:(tcp|ssl)|AUTO_SERVER|createTcpServer|createWebServer|webPort' \
    "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/h2/module.xml" \
    "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/"*.cli; then
  fail "runtime CP-3A habilita listener ou console H2"
fi
grep -Fq -- '--java 17' \
  "$REPOSITORY_ROOT/scripts/smoke-cp-3a-datasource.sh" ||
  fail "wrapper de runtime CP-3A não fixa Java 17"
if grep -Fq 'MIGRATION_CHECKPOINT=CP-3A' \
    "$REPOSITORY_ROOT/.github/workflows/validate.yml"; then
  for workflow_marker in \
    'JAVA17_HOME=$tools/jdk-17.0.20+8' \
    'H2_JAR=$archives/h2-2.4.240.jar' \
    './scripts/doctor.sh CP-3A --profile ci-h2 --ci' \
    './scripts/build-cp-3a.sh --profile ci-h2' \
    './scripts/smoke-cp-3a-datasource.sh \' \
    '--java 17 \' \
    'app/target/contract-results/cp-3a-ci-h2.json' \
    'name: cp-3a-portable-evidence'; do
    grep -Fq -- "$workflow_marker" \
      "$REPOSITORY_ROOT/.github/workflows/validate.yml" ||
      fail "CI portátil do CP-3A não contém: $workflow_marker"
  done
elif ! grep -Eq 'MIGRATION_CHECKPOINT=CP-3[B-K]' \
    "$REPOSITORY_ROOT/.github/workflows/validate.yml"; then
  fail "CI portátil não identifica o CP-3A nem um checkpoint posterior"
fi

for catalog_marker in \
  $'INC-011\tCP-3A\t' \
  $'INC-012\tCP-3A\t' \
  $'INC-013\tCP-3A\t'; do
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
  'POM permanece Java 8 por padrão' \
  'Fechamento do CP-3A — atividade 3.5' \
  '14/14' \
  'Oracle Database 19c RU 19.3' \
  'rollback para `migration/02-java8-wildfly26`'; do
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
grep -Fq -- \
  '- [x] 3.3 Produzir a matriz de cada dependência legada' \
  "$TASKS" ||
  fail "atividade 3.3 ainda não está marcada como concluída"
grep -Fq -- \
  '- [x] 3.4 Atualizar runtime, versão H2 de teste' \
  "$TASKS" ||
  fail "atividade 3.4 ainda não está marcada como concluída"
grep -Fq -- \
  '- [x] 3.5 Encerrar `CP-3A`' \
  "$TASKS" ||
  fail "atividade 3.5 ainda não está marcada como concluída"

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

if [[ -n "$PROMOTED_WAR_FILE$PROMOTED_CONTRACT_RESULT_FILE" ]]; then
  [[ -n "$PROMOTED_WAR_FILE" && -n "$PROMOTED_CONTRACT_RESULT_FILE" ]] ||
    fail "WAR e contrato promovidos devem ser informados juntos"
  [[ -f "$PROMOTED_WAR_FILE" ]] || fail "WAR promovido não existe"
  [[ -f "$PROMOTED_CONTRACT_RESULT_FILE" ]] ||
    fail "contrato promovido não existe"

  promoted_war_sha256="$(sha256sum "$PROMOTED_WAR_FILE" | awk '{print $1}')"
  temp_directory="$(
    mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3a-promoted.XXXXXXXX"
  )"
  trap 'rm -rf -- "$temp_directory"' EXIT
  unzip -p "$PROMOTED_WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class \
    >"$temp_directory/LegacyBuildMarker.class"
  javap -verbose "$temp_directory/LegacyBuildMarker.class" |
    grep -Fq 'major version: 61' ||
    fail "WAR promovido não contém bytecode Java 17 major 61"
  if unzip -Z1 "$PROMOTED_WAR_FILE" |
      grep -Eiq '^WEB-INF/lib/(h2|ojdbc)[^/]*\.jar$'; then
    fail "WAR promovido contém driver H2 ou Oracle"
  fi

  for marker in \
    '"qualification": "portable-ci"' \
    '"profile": "ci-h2"' \
    "\"warSha256\": \"$promoted_war_sha256\"" \
    '"runtime": "java17-wildfly26.1.3"'; do
    grep -Fq "$marker" "$PROMOTED_CONTRACT_RESULT_FILE" ||
      fail "contrato promovido não contém: $marker"
  done
  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$PROMOTED_CONTRACT_RESULT_FILE")" == "14" ]] ||
    fail "contrato promovido não contém os 14 cenários"
fi

if [[ -n "$ORACLE_CONTRACT_RESULT_FILE$ORACLE_STATE_RESULT_FILE$ORACLE_PERSISTENCE_RESULT_FILE" ]]; then
  [[ -n "$PROMOTED_WAR_FILE" ]] ||
    fail "resultados Oracle exigem também --promoted-war"
  [[ -n "$ORACLE_CONTRACT_RESULT_FILE" &&
     -n "$ORACLE_STATE_RESULT_FILE" &&
     -n "$ORACLE_PERSISTENCE_RESULT_FILE" ]] ||
    fail "contrato, estado e persistência Oracle devem ser informados juntos"

  for result_file in \
    "$ORACLE_CONTRACT_RESULT_FILE" \
    "$ORACLE_STATE_RESULT_FILE" \
    "$ORACLE_PERSISTENCE_RESULT_FILE"; do
    [[ -f "$result_file" ]] ||
      fail "resultado Oracle informado não existe: $result_file"
    grep -Fq '"qualification": "oracle-qualified"' "$result_file" ||
      fail "resultado Oracle dinâmico não está qualificado"
    grep -Fq '"profile": "oracle"' "$result_file" ||
      fail "resultado Oracle dinâmico não identifica o perfil"
    grep -Fq "\"warSha256\": \"$promoted_war_sha256\"" "$result_file" ||
      fail "resultado Oracle dinâmico não corresponde ao WAR promovido"
  done

  for marker in \
    '"runtime": "java17-wildfly26.1.3"' \
    '"qualification": "oracle-qualified"'; do
    grep -Fq "$marker" "$ORACLE_CONTRACT_RESULT_FILE" ||
      fail "contrato Oracle dinâmico não contém: $marker"
  done
  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$ORACLE_CONTRACT_RESULT_FILE")" == "14" ]] ||
    fail "contrato Oracle dinâmico não contém os 14 cenários"

  for result_file in \
    "$ORACLE_STATE_RESULT_FILE" \
    "$ORACLE_PERSISTENCE_RESULT_FILE"; do
    for marker in \
      '"runtime": "java17-wildfly26.1.3-ee8"' \
      '"databaseVersion": "19.3.0.0.0"' \
      '"jdbcDriver": "ojdbc7-12.1.0.2.0"'; do
      grep -Fq "$marker" "$result_file" ||
        fail "sonda Oracle dinâmica não contém: $marker"
    done
  done
  for marker in \
    '"schemaObjects": "passed"' \
    '"seedState": "passed"' \
    '"contractCreate": "passed"' \
    '"contractUploadBlob": "passed"' \
    '"contractXml": "passed"' \
    '"rejectedState": "passed"'; do
    grep -Fq "$marker" "$ORACLE_STATE_RESULT_FILE" ||
      fail "estado Oracle dinâmico não contém: $marker"
  done
  for marker in \
    '"mybatisCommit": "passed"' \
    '"mybatisRollback": "passed"' \
    '"timestampRoundTrip": "passed"' \
    '"blobRoundTrip": "passed"' \
    '"transientDataCleanup": "passed"'; do
    grep -Fq "$marker" "$ORACLE_PERSISTENCE_RESULT_FILE" ||
      fail "persistência Oracle dinâmica não contém: $marker"
  done

  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$ORACLE_CONTRACT_RESULT_FILE" "$ORACLE_STATE_RESULT_FILE" \
      "$ORACLE_PERSISTENCE_RESULT_FILE"; then
    fail "resultado Oracle dinâmico contém configuração sensível"
  fi
fi

printf 'OK: CP-3A/3.1 comprova o WAR da fase 2 no Java 17 sem correção\n'
printf 'OK: CP-3A/3.2 recompila no Java 17 com correções somente no harness\n'
printf 'OK: CP-3A/3.4 promove Java 17 e isola H2 2.4.240 do perfil Oracle\n'
printf 'OK: CP-3A/3.5 registra H2 portable-ci e Oracle oracle-qualified\n'
