#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS_FILE="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
WAR_FILE=""
H2_RESULT_FILE=""
H2_CONTRACT_FILE=""
ORACLE_RESULT_FILE=""
ORACLE_CONTRACT_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp3b.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3b.sh
  ./scripts/validate-cp-3b.sh --war ARQUIVO \
    [--h2-result ARQUIVO] [--h2-contract ARQUIVO] \
    [--oracle-result ARQUIVO] [--oracle-contract ARQUIVO]

Sem argumentos, valida a estrutura versionada do CP-3B. Os resultados
dinâmicos são opcionais durante o desenvolvimento e obrigatórios nas
qualificações correspondentes.
USAGE
}

fail() {
  printf 'FALHA CP-3B: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp3b.*)
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
    --h2-result)
      [[ $# -ge 2 ]] || fail "--h2-result exige um arquivo"
      H2_RESULT_FILE="$2"
      shift 2
      ;;
    --h2-contract)
      [[ $# -ge 2 ]] || fail "--h2-contract exige um arquivo"
      H2_CONTRACT_FILE="$2"
      shift 2
      ;;
    --oracle-result)
      [[ $# -ge 2 ]] || fail "--oracle-result exige um arquivo"
      ORACLE_RESULT_FILE="$2"
      shift 2
      ;;
    --oracle-contract)
      [[ $# -ge 2 ]] || fail "--oracle-contract exige um arquivo"
      ORACLE_CONTRACT_FILE="$2"
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

required_paths=(
  "app/pom.xml"
  "docs/cp-3b-core-dependencies.md"
  "docs/evidence/CP-3B.md"
  "docs/mybatis-persistence.md"
  "migration/steps/CP-3B-mybatis-3.5.19.md"
  "runtime/phase2/java8-wildfly26/war-libraries.txt"
  "runtime/phase3/java17-wildfly26/war-libraries.txt"
  "scripts/build-cp-3b.sh"
  "scripts/smoke-cp-3b-datasource.sh"
  "scripts/validate-cp-3b.sh"
)

for path in "${required_paths[@]}"; do
  [[ -f "$REPOSITORY_ROOT/$path" ]] ||
    fail "arquivo obrigatório ausente: $path"
done

grep -Fq '<mybatis.version>3.5.19</mybatis.version>' \
  "$REPOSITORY_ROOT/app/pom.xml" ||
  fail "POM não fixa MyBatis 3.5.19"

current_allowlist="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt"
phase2_allowlist="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
[[ "$(grep -Ec '^mybatis-[^/]+\.jar$' "$current_allowlist")" == "1" ]] ||
  fail "allowlist Java 17 deve conter exatamente um JAR MyBatis"
grep -Fxq 'mybatis-3.5.19.jar' "$current_allowlist" ||
  fail "allowlist Java 17 não contém MyBatis 3.5.19"
if grep -Fq 'mybatis-3.4.5.jar' "$current_allowlist"; then
  fail "allowlist Java 17 ainda contém MyBatis 3.4.5"
fi
grep -Fxq 'mybatis-3.4.5.jar' "$phase2_allowlist" ||
  fail "allowlist histórica da fase 2 foi alterada"
if grep -Fq 'mybatis-3.5.19.jar' "$phase2_allowlist"; then
  fail "MyBatis novo foi atribuído retroativamente à fase 2"
fi

for marker in \
  'MyBatis 3.5.19' \
  'MyBatis 3.4.5' \
  'logImpl' \
  'atividade 3.34' \
  'aliases' \
  'type handlers' \
  'reflexão' \
  'rollback de uma falha intencional'; do
  grep -Fiq "$marker" "$REPOSITORY_ROOT/docs/mybatis-persistence.md" ||
    fail "documentação MyBatis não contém: $marker"
done

validate_mybatis_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado MyBatis ausente: $file"
  for marker in \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"mybatisVersion": "3.5.19"' \
    '"mappers": "passed"' \
    '"aliases": "passed"' \
    '"typeHandlers": "passed"' \
    '"reflection": "passed"' \
    '"mybatisCommit": "passed"' \
    '"mybatisRollback": "passed"'; do
    grep -Fq "$marker" "$file" ||
      fail "resultado MyBatis não contém: $marker"
  done
  if grep -Eiq \
      'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' "$file"; then
    fail "resultado MyBatis contém configuração sensível"
  fi
}

validate_contract_result() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  [[ -f "$file" ]] || fail "resultado de contrato ausente: $file"
  grep -Fq "\"qualification\": \"$qualification\"" "$file" ||
    fail "contrato não contém qualificação $qualification"
  grep -Fq "\"profile\": \"$profile\"" "$file" ||
    fail "contrato não contém perfil $profile"
  [[ "$(grep -Ec \
      '^[[:space:]]+"[A-Za-z][A-Za-z0-9]*": "passed",?$' "$file")" == "14" ]] ||
    fail "contrato não contém os 14 cenários aprovados"
}

if grep -Fq -- \
    '- [x] 3.6 Atualizar MyBatis para 3.5.19' "$TASKS_FILE"; then
  for evidence in \
    "migration/evidence/CP-3B/mybatis-ci-h2.json" \
    "migration/evidence/CP-3B/mybatis-oracle.json"; do
    [[ -f "$REPOSITORY_ROOT/$evidence" ]] ||
      fail "evidência obrigatória da atividade 3.6 ausente: $evidence"
  done
  validate_mybatis_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-ci-h2.json" \
    portable-ci ci-h2
  validate_mybatis_result \
    "$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-oracle.json" \
    oracle-qualified oracle

  h2_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-ci-h2.json"
  oracle_evidence="$REPOSITORY_ROOT/migration/evidence/CP-3B/mybatis-oracle.json"
  h2_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' "$h2_evidence"
  )"
  oracle_source_commit="$(
    sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' "$oracle_evidence"
  )"
  h2_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' "$h2_evidence"
  )"
  oracle_war_sha256="$(
    sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' "$oracle_evidence"
  )"
  [[ "$h2_source_commit" =~ ^[0-9a-f]{40}$ &&
     "$h2_source_commit" == "$oracle_source_commit" ]] ||
    fail "evidências H2 e Oracle não usam o mesmo commit-fonte"
  [[ "$h2_war_sha256" =~ ^[0-9a-f]{64}$ &&
     "$h2_war_sha256" == "$oracle_war_sha256" ]] ||
    fail "evidências H2 e Oracle não usam o mesmo WAR"
  git -C "$REPOSITORY_ROOT" cat-file -e \
    "${h2_source_commit}^{commit}" 2>/dev/null ||
    fail "commit-fonte das evidências MyBatis não existe"
fi

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"
  [[ "$(grep -Ec '^WEB-INF/lib/mybatis-[^/]+\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt")" == "1" ]] ||
    fail "WAR deve conter exatamente um JAR MyBatis"
  grep -Fxq 'WEB-INF/lib/mybatis-3.5.19.jar' \
    "$TEMP_DIRECTORY/war-entries.txt" ||
    fail "WAR não contém MyBatis 3.5.19"
  if grep -Fq 'WEB-INF/lib/mybatis-3.4.5.jar' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR ainda contém MyBatis 3.4.5"
  fi
  war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
else
  war_sha256=""
fi

if [[ -n "$H2_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-result exige --war"
  validate_mybatis_result "$H2_RESULT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$H2_RESULT_FILE" ||
    fail "resultado MyBatis H2 não corresponde ao WAR"
fi
if [[ -n "$H2_CONTRACT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--h2-contract exige --war"
  validate_contract_result "$H2_CONTRACT_FILE" portable-ci ci-h2
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$H2_CONTRACT_FILE" ||
    fail "contrato H2 não corresponde ao WAR"
fi
if [[ -n "$ORACLE_RESULT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-result exige --war"
  validate_mybatis_result \
    "$ORACLE_RESULT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$ORACLE_RESULT_FILE" ||
    fail "resultado MyBatis Oracle não corresponde ao WAR"
  grep -Fq '"databaseVersion": "19.3.0.0.0"' "$ORACLE_RESULT_FILE" ||
    fail "resultado MyBatis Oracle não identifica o RU 19.3"
fi
if [[ -n "$ORACLE_CONTRACT_FILE" ]]; then
  [[ -n "$WAR_FILE" ]] || fail "--oracle-contract exige --war"
  validate_contract_result \
    "$ORACLE_CONTRACT_FILE" oracle-qualified oracle
  grep -Fq "\"warSha256\": \"$war_sha256\"" "$ORACLE_CONTRACT_FILE" ||
    fail "contrato Oracle não corresponde ao WAR"
fi

printf 'OK: MyBatis 3.5.19 isolado, auditado e compatível com o CP-3B\n'
