#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
RESULT_DIRECTORY="$ROOT/app/target/contract-results"
NON_INTERACTIVE=false
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3h-oracle.XXXXXXXX)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3h-oracle.sh [--env ARQUIVO] [--war ARQUIVO]
    [--result-directory DIRETORIO] [--non-interactive]

Consulta a identidade do Oracle 19c com ojdbc17, executa os 15 contratos
externos no WildFly 41/Java 21 e grava evidência sanitizada do CP-3H/3.38.
USAGE
}

fail() {
  printf 'FALHA CP-3H/3.38: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3h-oracle.*) rm -rf -- "$TEMP_DIRECTORY" ;;
    *) printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2 ;;
  esac
}
trap cleanup EXIT

read_env_value() {
  local wanted="$1" file="$2" line key value result="" count=0
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "${line:0:1}" == '#' ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    [[ "$key" == "$wanted" ]] || continue
    value="${line#*=}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done <"$file"
  (( count == 1 )) || return 1
  printf '%s' "$result"
}

configuration_value() {
  local key="$1"
  local exported="${!key:-}"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    read_env_value "$key" "$ENV_FILE" || true
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) [[ $# -ge 2 ]] || fail '--env exige um arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --result-directory) [[ $# -ge 2 ]] || fail '--result-directory exige um diretório'; RESULT_DIRECTORY="$2"; shift 2 ;;
    --non-interactive) NON_INTERACTIVE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ -f "$ENV_FILE" ]] || fail "arquivo .env ausente: ${ENV_FILE#"$ROOT/"}"
[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
mkdir -p "$RESULT_DIRECTORY"

doctor_args=(CP-3G --profile oracle --env "$ENV_FILE")
[[ "$NON_INTERACTIVE" == true ]] && doctor_args+=(--non-interactive)
"$ROOT/scripts/doctor.sh" "${doctor_args[@]}"
"$ROOT/scripts/validate-cp-3h-datasource.sh" \
  --env "$ENV_FILE" --war "$WAR_FILE" --verify-external

JAVA_HOME_VALUE="$(configuration_value JAVA21_HOME)"
WILDFLY_HOME_VALUE="$(configuration_value WILDFLY41_HOME)"
OJDBC17_JAR_VALUE="$(configuration_value OJDBC17_JAR)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$JAVA_HOME_VALUE/bin/javac" ]] ||
  fail 'JAVA21_HOME não aponta para um JDK completo'
[[ -x "$WILDFLY_HOME_VALUE/bin/standalone.sh" ]] ||
  fail 'WILDFLY41_HOME não aponta para WildFly 41'
[[ -f "$OJDBC17_JAR_VALUE" ]] || fail 'OJDBC17_JAR não existe'

java_version="$($JAVA_HOME_VALUE/bin/java -version 2>&1)"
[[ "$java_version" == *'openjdk version "21.0.12"'* &&
   "$java_version" == *'Temurin-21.0.12+8'* ]] ||
  fail 'JVM observada não é Temurin 21.0.12+8'
jvm_observed="$(printf '%s\n' "$java_version" | sed -n '2p' | sed 's/^OpenJDK /OpenJDK /')"

"$JAVA_HOME_VALUE/bin/javac" -encoding UTF-8 -cp "$OJDBC17_JAR_VALUE" \
  -d "$TEMP_DIRECTORY" "$ROOT/scripts/ValidateCp3hOracleVersion.java"
ORACLE_DB_URL="$(configuration_value ORACLE_DB_URL)" \
ORACLE_DB_USER="$(configuration_value ORACLE_DB_USER)" \
ORACLE_DB_PASSWORD="$(configuration_value ORACLE_DB_PASSWORD)" \
  "$JAVA_HOME_VALUE/bin/java" -cp "$TEMP_DIRECTORY:$OJDBC17_JAR_VALUE" \
  ValidateCp3hOracleVersion >"$TEMP_DIRECTORY/oracle-version.tsv"

database_product="$(sed -n 's/^databaseProduct=//p' "$TEMP_DIRECTORY/oracle-version.tsv")"
database_version="$(sed -n 's/^databaseVersion=//p' "$TEMP_DIRECTORY/oracle-version.tsv")"
driver_version="$(sed -n 's/^driverVersion=//p' "$TEMP_DIRECTORY/oracle-version.tsv")"
[[ "$database_product" == *'Oracle Database 19c'* ]] || fail 'produto Oracle 19c não confirmado'
[[ "$database_version" == '19.3.0.0.0' ]] || fail 'RU Oracle não é 19.3.0.0.0'
[[ "$driver_version" == 23.26.2.0.0* ]] || fail 'ojdbc17 23.26.2.0.0 não foi observado'

contract_result="$RESULT_DIRECTORY/cp3h-3.38-oracle-contract.json"
diagnostic_log="$RESULT_DIRECTORY/cp3h-3.38-oracle-server.log"
"$ROOT/scripts/smoke-wildfly41-datasource.sh" \
  --profile oracle --env "$ENV_FILE" --war "$WAR_FILE" \
  --result "$contract_result" --diagnostic-log "$diagnostic_log"
for marker in \
  '"qualification": "oracle-qualified"' \
  '"profile": "oracle"' \
  '"runtime": "java21-wildfly41.0.0"' \
  '"health": "passed"' \
  '"persistedState": "passed"'; do
  grep -Fq "$marker" "$contract_result" || fail "contrato Oracle não contém: $marker"
done
scenario_count="$(grep -Ec '"(health|list|create|detail|session|upload|uploadLimit|xmlForm|xmlValid|xmlInvalidXsd|xmlValidatorRejected|xmlXxe|xmlEntityExpansion|protectedFragments|persistedState)": "passed"' "$contract_result")"
[[ "$scenario_count" == 15 ]] || fail "suíte Oracle retornou $scenario_count cenários aprovados"

wildfly_observed="$(sed -n 's/.*WFLYSRV0049: \(WildFly [0-9][^$]*\) starting/\1/p' "$diagnostic_log" | head -n 1)"
[[ "$wildfly_observed" == 'WildFly 41.0.0.Final (WildFly Core 33.0.0.Final)' ]] ||
  fail "WildFly observado diverge: $wildfly_observed"

source_commit="$(git -C "$ROOT" rev-parse HEAD)"
working_tree=true
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] && working_tree=false
war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
evidence="$ROOT/migration/evidence/CP-3H/oracle-qualification.json"
cat >"$evidence" <<EOF
{
  "schema": "wildfly-migration-cp3h-oracle-qualification/v1",
  "checkpoint": "CP-3H",
  "activity": "3.38",
  "qualification": "oracle-qualified",
  "profile": "oracle",
  "sourceCommit": "$source_commit",
  "workingTree": $working_tree,
  "warSha256": "$war_sha256",
  "databaseProduct": "$database_product",
  "databaseVersion": "$database_version",
  "releaseUpdate": "$database_version",
  "jdbcDriver": "ojdbc17-$driver_version",
  "jvm": "$jvm_observed",
  "wildfly": "$wildfly_observed",
  "jndiName": "java:/jdbc/MigrationDS",
  "contractScenarios": $scenario_count,
  "checks": {
    "oracleConnection": "passed",
    "releaseUpdate": "passed",
    "driver": "passed",
    "jvm": "passed",
    "wildfly": "passed",
    "contractSuite": "passed",
    "sanitizedEvidence": "passed"
  },
  "result": "passed"
}
EOF

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|ORACLE_DB_PASSWORD|password|user-name|connection-url|senha' "$evidence"; then
  fail 'evidência Oracle contém configuração sensível'
fi

"$ROOT/scripts/validate-cp-3h-oracle-qualification.sh" --war "$WAR_FILE"

printf 'OK: CP-3H/3.38 Oracle 19c RU %s, ojdbc17 %s, %s e %s; evidência em %s\n' \
  "$database_version" "$driver_version" "$jvm_observed" "$wildfly_observed" \
  "${evidence#"$ROOT/"}"
