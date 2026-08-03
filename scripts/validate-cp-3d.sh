#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVIDENCE_DIRECTORY="$REPOSITORY_ROOT/migration/evidence/CP-3D"
PORTABLE_RESULT="$EVIDENCE_DIRECTORY/portable-ci.json"
ORACLE_RESULT="$EVIDENCE_DIRECTORY/oracle-qualified.json"
MANIFEST="$EVIDENCE_DIRECTORY/manifest.properties"
BASELINE="$REPOSITORY_ROOT/migration/baselines/01-legacy/contract-scenarios.tsv"

fail() {
  printf 'FALHA CP-3D: %s\n' "$1" >&2
  exit 1
}

property() {
  local key="$1"
  local file="$2"
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, index($0, "=") + 1); found = 1; exit } END { if (!found) exit 1 }' "$file"
}

json_field() {
  local key="$1"
  local file="$2"
  sed -n -E "s/^[[:space:]]*\"${key}\": \"([^\"]*)\"[,]?$/\1/p" "$file" | head -n 1
}

for file in "$PORTABLE_RESULT" "$ORACLE_RESULT" "$MANIFEST" \
  "$BASELINE" "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt"; do
  [[ -f "$file" ]] || fail "arquivo obrigatório ausente: ${file#"$REPOSITORY_ROOT/"}"
done

"$REPOSITORY_ROOT/scripts/validate-cp-3d-tiles-tld.sh"

for result in "$PORTABLE_RESULT" "$ORACLE_RESULT"; do
  grep -Fq '"schema": "wildfly-migration-cp3d-gate/v1"' "$result" ||
    fail "schema CP-3D ausente em ${result##*/}"
  grep -Fq '"checkpoint": "CP-3D"' "$result" ||
    fail "checkpoint CP-3D ausente em ${result##*/}"
  grep -Fq '"runtime": "java17-wildfly26.1.3-ee8"' "$result" ||
    fail "runtime Java 17/WildFly 26 ausente em ${result##*/}"
  grep -Fq '"baselineComparison": "passed"' "$result" ||
    fail "comparação com baseline não aprovada em ${result##*/}"
  grep -Fq '"scenarioCount": 14' "$result" ||
    fail "quantidade de contratos não é 14 em ${result##*/}"
  grep -Fq '"result": "passed"' "$result" ||
    fail "resultado não aprovado em ${result##*/}"
done

portable_source="$(json_field sourceCommit "$PORTABLE_RESULT")"
oracle_source="$(json_field sourceCommit "$ORACLE_RESULT")"
portable_war="$(json_field warSha256 "$PORTABLE_RESULT")"
oracle_war="$(json_field warSha256 "$ORACLE_RESULT")"
manifest_source="$(property sourceCommit "$MANIFEST")"
manifest_war="$(property war.sha256 "$MANIFEST")"

[[ "$portable_source" =~ ^[[:xdigit:]]{40}$ ]] || fail "sourceCommit portable inválido"
[[ "$oracle_source" == "$portable_source" ]] || fail "H2 e Oracle usam commits diferentes"
[[ "$portable_war" =~ ^[[:xdigit:]]{64}$ ]] || fail "warSha256 portable inválido"
[[ "$oracle_war" == "$portable_war" ]] || fail "H2 e Oracle usam WARs diferentes"
[[ "$manifest_source" == "$portable_source" ]] || fail "manifesto e evidência usam commits diferentes"
[[ "$manifest_war" == "$portable_war" ]] || fail "manifesto e evidência usam WARs diferentes"

for scenario in $(awk -F '\t' 'NR > 1 { print $1 }' "$BASELINE"); do
  grep -Fq "\"$scenario\": \"passed\"" "$PORTABLE_RESULT" ||
    fail "contrato $scenario não aprovado no portable-ci"
  grep -Fq "\"$scenario\": \"passed\"" "$ORACLE_RESULT" ||
    fail "contrato $scenario não aprovado no oracle-qualified"
done

grep -Fq '"qualification": "portable-ci"' "$PORTABLE_RESULT" ||
  fail 'qualificação portable-ci ausente'
grep -Fq '"qualification": "oracle-qualified"' "$ORACLE_RESULT" ||
  fail 'qualificação oracle-qualified ausente'
grep -Fq '"databaseVersion": "19.3.0.0.0"' "$ORACLE_RESULT" ||
  fail 'versão Oracle 19.3.0.0.0 ausente'
grep -Fq '"jdbcDriver": "ojdbc17-23.26.2.0.0"' "$ORACLE_RESULT" ||
  fail 'driver ojdbc17 aprovado ausente'

for key_value in \
  'schema=wildfly-migration-cp3d-manifest/v1' \
  'checkpoint=CP-3D' \
  'baseline=migration/02-java8-wildfly26' \
  'runtime.java=17.0.20+8' \
  'runtime.wildfly=26.1.3.Final' \
  'runtime.ee=Jakarta-EE-Web-Profile-8.0-javax' \
  'runtime.maven=3.9.16' \
  'war.path=app/target/wildfly-migration.war' \
  'war.bytecode.major=61' \
  'war.libraryCount=17' \
  'contract.scenarioCount=14' \
  'baseline.comparison=passed' \
  'qualification.portable-ci=passed' \
  'qualification.oracle-qualified=passed' \
  'result=passed'; do
  grep -Fxq "$key_value" "$MANIFEST" ||
    fail "manifesto não contém $key_value"
done

for marker in \
  'tiles-2.1.4' \
  'tld-2.0-javax' \
  'log4j-over-slf4j-1.7.36' \
  'reflections-0.10.2' \
  'commons-fileupload-1.6.0' \
  'deferred-replacement=CP-3G'; do
  grep -Fq "$marker" "$MANIFEST" ||
    fail "exceção/adiamento ausente no manifesto: $marker"
done

printf 'OK: CP-3D validado — 14/14 contratos H2 e Oracle, WAR e manifesto coerentes\n'
