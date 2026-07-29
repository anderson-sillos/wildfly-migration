#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIRECTORY="$REPOSITORY_ROOT/migration/baselines/01-legacy"
BASELINE_PROPERTIES="$BASELINE_DIRECTORY/baseline.properties"
BASELINE_SCENARIOS="$BASELINE_DIRECTORY/contract-scenarios.tsv"
BASELINE_ORACLE_STATE="$BASELINE_DIRECTORY/oracle-persisted-state.tsv"
LIMITATIONS_FILE="$REPOSITORY_ROOT/docs/h2-oracle-differences.md"
WAR_FILE=""
ORACLE_STATE_RESULT=""
ORACLE_PERSISTENCE_RESULT=""
SUMMARY_RESULT=""
CONTRACT_RESULTS=()

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-2d-phase-comparison.sh
  ./scripts/validate-cp-2d-phase-comparison.sh \
    --war ARQUIVO \
    --contract-result ARQUIVO [--contract-result ARQUIVO] \
    [--oracle-state-result ARQUIVO] \
    [--oracle-persistence-result ARQUIVO] \
    [--summary-result ARQUIVO]

Sem argumentos, valida a estrutura da comparação. Com resultados dinâmicos,
compara os 14 contratos da fase 2 com a fase 1. O resumo exige os dois perfis,
o estado Oracle e a sonda de persistência Oracle.
USAGE
}

fail() {
  printf 'FALHA CP-2D comparação: %s\n' "$1" >&2
  exit 1
}

property() {
  local key="$1"
  local value
  value="$(
    awk -F= -v wanted="$key" \
      '$1 == wanted { sub(/^[^=]*=/, ""); print }' \
      "$BASELINE_PROPERTIES"
  )"
  [[ -n "$value" ]] || fail "propriedade do baseline ausente: $key"
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
    --oracle-state-result)
      [[ $# -ge 2 ]] || fail "--oracle-state-result exige um arquivo"
      ORACLE_STATE_RESULT="$2"
      shift 2
      ;;
    --oracle-persistence-result)
      [[ $# -ge 2 ]] || fail "--oracle-persistence-result exige um arquivo"
      ORACLE_PERSISTENCE_RESULT="$2"
      shift 2
      ;;
    --summary-result)
      [[ $# -ge 2 ]] || fail "--summary-result exige um arquivo"
      SUMMARY_RESULT="$2"
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
  "$BASELINE_PROPERTIES" \
  "$BASELINE_SCENARIOS" \
  "$BASELINE_ORACLE_STATE" \
  "$LIMITATIONS_FILE" \
  "$REPOSITORY_ROOT/scripts/ValidatePhase2OracleState.java" \
  "$REPOSITORY_ROOT/scripts/validate-cp-2d-oracle-state.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-2d-h2.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-2d-oracle.sh"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for script in \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" \
  "$REPOSITORY_ROOT/scripts/validate-cp-2d-oracle-state.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-2d-h2.sh" \
  "$REPOSITORY_ROOT/scripts/qualify-cp-2d-oracle.sh"; do
  bash -n "$script" || fail "sintaxe inválida: ${script#"$REPOSITORY_ROOT/"}"
done

for preserve_marker in \
  '--preserve-oracle-smokes' \
  'PRESERVE_ORACLE_SMOKES=true' \
  'dados LAB-SMOKE-* preservados temporariamente para comparação'; do
  grep -Fq -- "$preserve_marker" \
    "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
    fail "smoke não contém o controle transitório: $preserve_marker"
done
for portable_result_marker in \
  'PORTABLE_CONTRACT_BACKUP=' \
  'cp "$PORTABLE_CONTRACT_RESULT" "$PORTABLE_CONTRACT_BACKUP"' \
  'cp "$PORTABLE_CONTRACT_BACKUP" "$PORTABLE_CONTRACT_RESULT"'; do
  grep -Fq "$portable_result_marker" \
    "$REPOSITORY_ROOT/scripts/qualify-cp-2d-oracle.sh" ||
    fail "qualificação Oracle não preserva o relatório H2: $portable_result_marker"
done

[[ "$(property phase)" == "1" ]] ||
  fail "referência funcional não identifica a fase 1"
[[ "$(property tag)" == "migration/01-legacy-baseline" ]] ||
  fail "referência funcional não identifica a tag pública da fase 1"
[[ "$(property contract.scenarioCount)" == "14" ]] ||
  fail "baseline não contém os 14 contratos esperados"
grep -Fq \
  $'contract\tupload\tcontrato-upload.txt,text/plain,46 bytes,SHA-256,BLOB\t' \
  "$BASELINE_ORACLE_STATE" ||
  fail "metadado histórico de tamanho do upload não foi preservado"

for limitation_marker in \
  'H2 1.4.200 em `MODE=Oracle`' \
  'timestamps' \
  'LOB binário' \
  'H2 nunca decide qual comportamento prevalece'; do
  grep -Fq "$limitation_marker" "$LIMITATIONS_FILE" ||
    fail "limitações portáteis não contêm: $limitation_marker"
done

if [[ "${#CONTRACT_RESULTS[@]}" -eq 0 &&
      -z "$ORACLE_STATE_RESULT$ORACLE_PERSISTENCE_RESULT$SUMMARY_RESULT" ]]; then
  printf 'OK: estrutura da comparação integral da fase 2 validada\n'
  exit 0
fi

[[ -f "$WAR_FILE" ]] || fail "WAR atual não foi informado"
"$REPOSITORY_ROOT/scripts/validate-cp-2c.sh" --war "$WAR_FILE"

current_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
source_commit="${MIGRATION_SOURCE_COMMIT:-$current_commit}"
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
scenario_count="$(property contract.scenarioCount)"
seen_h2=false
seen_oracle=false

for result_file in "${CONTRACT_RESULTS[@]}"; do
  [[ -f "$result_file" ]] ||
    fail "resultado de contrato não existe: $result_file"
  if grep -Fq '"profile": "ci-h2"' "$result_file"; then
    [[ "$seen_h2" == false ]] || fail "resultado H2 duplicado"
    seen_h2=true
    expected_qualification='"qualification": "portable-ci"'
  elif grep -Fq '"profile": "oracle"' "$result_file"; then
    [[ "$seen_oracle" == false ]] || fail "resultado Oracle duplicado"
    seen_oracle=true
    expected_qualification='"qualification": "oracle-qualified"'
  else
    fail "resultado não identifica perfil conhecido"
  fi

  for marker in \
    '"schema": "wildfly-migration-contract-result/v1"' \
    "$expected_qualification" \
    "\"commit\": \"$current_commit\"" \
    "\"sourceCommit\": \"$source_commit\"" \
    "\"warSha256\": \"$war_sha256\"" \
    '"runtime": "java8-wildfly26.1.3"'; do
    grep -Fq "$marker" "$result_file" ||
      fail "contrato atual não contém: $marker"
  done

  while IFS=$'\t' read -r scenario expected _; do
    [[ "$scenario" == "scenario" ]] && continue
    grep -Fq "\"$scenario\": \"$expected\"" "$result_file" ||
      fail "contrato divergiu do baseline no cenário $scenario"
  done <"$BASELINE_SCENARIOS"

  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' \
      "$result_file")" == "$scenario_count" ]] ||
    fail "contrato não contém exatamente $scenario_count cenários"
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$result_file"; then
    fail "contrato contém configuração sensível"
  fi
done

if [[ -n "$ORACLE_STATE_RESULT" ]]; then
  [[ -f "$ORACLE_STATE_RESULT" ]] ||
    fail "resultado do estado Oracle não existe"
  for marker in \
    '"schema": "wildfly-migration-phase2-oracle-state/v1"' \
    '"qualification": "oracle-qualified"' \
    "\"commit\": \"$source_commit\"" \
    "\"sourceCommit\": \"$source_commit\"" \
    "\"warSha256\": \"$war_sha256\"" \
    '"databaseVersion": "19.3.0.0.0"' \
    '"jdbcDriver": "ojdbc7-12.1.0.2.0"' \
    '"contractUploadBytes": 44' \
    '"contractUploadSha256": "8eb0c39e90e87a89c57313d37988ff2a3b67bb43b57ce89956f447a431dc7a3c"' \
    '"schemaObjects": "passed"' \
    '"seedState": "passed"' \
    '"contractCreate": "passed"' \
    '"contractUploadBlob": "passed"' \
    '"contractXml": "passed"' \
    '"rejectedState": "passed"'; do
    grep -Fq "$marker" "$ORACLE_STATE_RESULT" ||
      fail "estado Oracle atual não contém: $marker"
  done
fi

if [[ -n "$ORACLE_PERSISTENCE_RESULT" ]]; then
  [[ -f "$ORACLE_PERSISTENCE_RESULT" ]] ||
    fail "resultado da persistência Oracle não existe"
  for marker in \
    '"schema": "wildfly-migration-oracle-persistence/v1"' \
    '"qualification": "oracle-qualified"' \
    "\"commit\": \"$current_commit\"" \
    "\"sourceCommit\": \"$current_commit\"" \
    "\"warSha256\": \"$war_sha256\"" \
    '"mybatisCommit": "passed"' \
    '"mybatisRollback": "passed"' \
    '"timestampRoundTrip": "passed"' \
    '"blobRoundTrip": "passed"' \
    '"transientDataCleanup": "passed"'; do
    grep -Fq "$marker" "$ORACLE_PERSISTENCE_RESULT" ||
      fail "persistência Oracle atual não contém: $marker"
  done
fi

for result_file in \
  "$ORACLE_STATE_RESULT" \
  "$ORACLE_PERSISTENCE_RESULT"; do
  [[ -n "$result_file" ]] || continue
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
      "$result_file"; then
    fail "evidência Oracle contém configuração sensível"
  fi
done

if [[ -n "$SUMMARY_RESULT" ]]; then
  [[ "$seen_h2" == true && "$seen_oracle" == true ]] ||
    fail "resumo exige os contratos H2 e Oracle"
  [[ -n "$ORACLE_STATE_RESULT" &&
     -n "$ORACLE_PERSISTENCE_RESULT" ]] ||
    fail "resumo exige as duas sondas Oracle"
  summary_directory="$(dirname "$SUMMARY_RESULT")"
  install -d -m 0755 "$summary_directory"
  summary_temporary="$SUMMARY_RESULT.tmp.$$"
  {
    printf '{\n'
    printf '  "schema": "wildfly-migration-phase2-comparison/v1",\n'
    printf '  "checkpoint": "CP-2D",\n'
    printf '  "sourceCommit": "%s",\n' "$source_commit"
    printf '  "baselineTag": "migration/01-legacy-baseline",\n'
    printf '  "baselineWarSha256": "%s",\n' \
      "$(property war.sha256)"
    printf '  "phase2WarSha256": "%s",\n' "$war_sha256"
    printf '  "scenarioCount": %s,\n' "$scenario_count"
    printf '  "portableCi": "passed-with-documented-limitations",\n'
    printf '  "oracleQualified": "passed",\n'
    printf '  "oraclePersistedState": "matches-phase1",\n'
    printf '  "baselineUploadMetadata": "46-documented-44-observed",\n'
    printf '  "portableLimitations": "docs/h2-oracle-differences.md",\n'
    printf '  "result": "passed"\n'
    printf '}\n'
  } >"$summary_temporary"
  mv "$summary_temporary" "$SUMMARY_RESULT"
fi

printf 'OK: fase 2 preserva os %s contratos da fase 1' "$scenario_count"
if [[ "$seen_h2" == true ]]; then
  printf ', H2 aprovado somente como portable-ci'
fi
if [[ "$seen_oracle" == true ]]; then
  printf ', Oracle aprovado como oracle-qualified'
fi
if [[ -n "$ORACLE_STATE_RESULT" ]]; then
  printf ', estado Oracle oficial equivalente'
fi
printf '\n'
