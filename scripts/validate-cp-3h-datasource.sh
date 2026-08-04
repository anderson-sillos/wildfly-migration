#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
VERIFY_EXTERNAL=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3h-datasource.sh [--env ARQUIVO] [--war ARQUIVO]
    [--verify-external]

Valida estaticamente os módulos e perfis H2/Oracle do CP-3H. A opção
--verify-external também confere os arquivos indicados no .env e seus SHA-256;
ela deve ser usada somente em um ambiente que recebeu os binários externos.
USAGE
}

fail() {
  printf 'FALHA CP-3H/3.37: %s\n' "$1" >&2
  exit 1
}

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) [[ $# -ge 2 ]] || fail '--env exige um arquivo'; ENV_FILE="$2"; shift 2 ;;
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --verify-external) VERIFY_EXTERNAL=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"
H2_MODULE="$ROOT/runtime/phase3/java21-wildfly41/h2/module.xml"
ORACLE_MODULE="$ROOT/runtime/phase3/java21-wildfly41/ojdbc17/module.xml.template"
H2_PROFILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/ci-h2.cli"
ORACLE_PROFILE="$ROOT/runtime/phase3/java21-wildfly41/profiles/oracle.cli"
H2_EVIDENCE="$ROOT/migration/evidence/CP-3H/datasource-ci-h2.json"
ORACLE_EVIDENCE="$ROOT/migration/evidence/CP-3H/datasource-oracle.json"

for path in \
  "$MANIFEST" "$H2_MODULE" "$ORACLE_MODULE" "$H2_PROFILE" "$ORACLE_PROFILE" \
  "$ROOT/runtime/phase3/java21-wildfly41/README.md" \
  "$ROOT/migration/steps/CP-3H-ojdbc17-datasource.md" \
  "$H2_EVIDENCE" "$ORACLE_EVIDENCE"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

manifest_row() {
  awk -F '\t' -v component="$1" '$1 == component { print; found=1; exit }
    END { if (!found) exit 1 }' "$MANIFEST"
}

ojdbc_row="$(manifest_row ojdbc17 || true)"
[[ -n "$ojdbc_row" ]] || fail 'ojdbc17 não está no manifesto Java 21/WildFly 41'
IFS=$'\t' read -r component version archive origin license sha published lifecycle scope <<< "$ojdbc_row"
[[ "$version" == '23.26.2.0.0' && "$archive" == 'ojdbc17.jar' ]] ||
  fail 'versão ou nome do ojdbc17 diverge do manifesto final'
[[ "$origin" == 'https://repo.maven.apache.org/maven2/com/oracle/database/jdbc/ojdbc17/23.26.2.0.0/ojdbc17-23.26.2.0.0.jar' ]] ||
  fail 'origem do ojdbc17 diverge do Maven Central fixado'
[[ "$license" == 'Oracle Free Use Terms and Conditions (FUTC)' ]] ||
  fail 'licença FUTC não registrada para o ojdbc17'
[[ "$sha" == '96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb' &&
   "$published" == 'sha256:96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb' ]] ||
  fail 'checksum do ojdbc17 diverge do valor fixado'
[[ "$scope" == 'CP-3H-to-CP-3K' ]] || fail 'escopo do ojdbc17 não cobre CP-3H até CP-3K'

h2_row="$(manifest_row h2 || true)"
[[ -n "$h2_row" ]] || fail 'H2 não está no manifesto final'
IFS=$'\t' read -r component version archive origin license sha published lifecycle scope <<< "$h2_row"
[[ "$version" == '2.4.240' && "$archive" == 'h2-2.4.240.jar' ]] ||
  fail 'H2 do perfil portátil diverge do manifesto'

grep -Fq 'driver-module-name=com.oracle.ojdbc17' "$ORACLE_PROFILE" ||
  fail 'perfil Oracle não registra o módulo com.oracle.ojdbc17'
grep -Fq 'jndi-name=java:/jdbc/MigrationDS' "$ORACLE_PROFILE" ||
  fail 'perfil Oracle não publica java:/jdbc/MigrationDS'
grep -Fq 'check-valid-connection-sql="SELECT 1 FROM DUAL"' "$ORACLE_PROFILE" ||
  fail 'perfil Oracle não valida a conexão com SELECT 1 FROM DUAL'
grep -Fq 'min-pool-size=1,max-pool-size=10' "$ORACLE_PROFILE" ||
  fail 'pool Oracle não está delimitado entre 1 e 10 conexões'
grep -Fq 'driver-module-name=h2-cp3f' "$H2_PROFILE" ||
  fail 'perfil H2 não registra o driver h2-cp3f'
grep -Fq 'jndi-name=java:/jdbc/MigrationDS' "$H2_PROFILE" ||
  fail 'perfil H2 não publica java:/jdbc/MigrationDS'
grep -Fq 'jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1' "$H2_PROFILE" ||
  fail 'perfil H2 não usa banco em memória em modo Oracle'
grep -Fq 'min-pool-size=1,max-pool-size=5' "$H2_PROFILE" ||
  fail 'pool H2 não está delimitado entre 1 e 5 conexões'
grep -Fq 'name="com.oracle.ojdbc17"' "$ORACLE_MODULE" ||
  fail 'module.xml Oracle não declara com.oracle.ojdbc17'
grep -Fq 'resource-root path="ojdbc17.jar"' "$ORACLE_MODULE" ||
  fail 'module.xml Oracle não referencia ojdbc17.jar'
grep -Fq 'name="com.h2database.h2.cp3f"' "$H2_MODULE" ||
  fail 'module.xml H2 não declara o slot cp3f'
grep -Fq 'resource-root path="h2-2.4.240.jar"' "$H2_MODULE" ||
  fail 'module.xml H2 não referencia H2 2.4.240'

if grep -Eiq '<artifactId>ojdbc(7|8|10|11|17)</artifactId>|<artifactId>h2</artifactId>' \
    "$ROOT/app/pom.xml"; then
  fail 'driver Oracle/H2 não pode ser dependência do WAR'
fi
if grep -Eiq 'ojdbc17|ojdbc7' "$ROOT/runtime/portable-runtime-cache.sha256" \
    "$ROOT/runtime/portable-runtime-sources.tsv"; then
  fail 'ojdbc17/ojdbc7 não pode entrar no cache portátil'
fi

for evidence in "$H2_EVIDENCE" "$ORACLE_EVIDENCE"; do
  for marker in \
    '"schema": "wildfly-migration-cp3h-datasource/v1"' \
    '"activity": "3.37"' \
    '"jndiName": "java:/jdbc/MigrationDS"' \
    '"warDrivers": "absent"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$evidence" || fail "evidência não contém $marker: ${evidence##*/}"
  done
  grep -Eq '"sourceCommit": "[0-9a-f]{40}"' "$evidence" ||
    fail "evidência sem sourceCommit completo: ${evidence##*/}"
  grep -Fq '"workingTree": false' "$evidence" ||
    fail "evidência exige workingTree=false: ${evidence##*/}"
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|ORACLE_DB_PASSWORD|password|user-name|connection-url|senha' "$evidence"; then
    fail "evidência contém segredo ou URL Oracle: ${evidence##*/}"
  fi
done

if [[ -f "$WAR_FILE" ]]; then
  war_entries="$(mktemp)"
  trap 'rm -f "$war_entries"' EXIT
  jar tf "$WAR_FILE" >"$war_entries"
  if grep -Eiq '^WEB-INF/lib/(ojdbc|h2-)[^/]*\.jar$' "$war_entries"; then
    fail 'WAR empacota H2 ou driver Oracle; ambos devem ser módulos externos'
  fi
fi

if [[ "$VERIFY_EXTERNAL" == true ]]; then
  [[ -f "$ENV_FILE" ]] || fail "arquivo .env ausente: ${ENV_FILE#$ROOT/}"
  ojdbc_path="$(read_env_value OJDBC17_JAR "$ENV_FILE" || true)"
  ojdbc_configured_sha="$(read_env_value OJDBC17_SHA256 "$ENV_FILE" || true)"
  h2_path="$(read_env_value H2_JAR "$ENV_FILE" || true)"
  [[ -f "$ojdbc_path" ]] || fail 'OJDBC17_JAR não aponta para um arquivo existente'
  [[ "$(basename "$ojdbc_path")" == 'ojdbc17.jar' ]] || fail 'OJDBC17_JAR deve terminar em ojdbc17.jar'
  [[ "$ojdbc_configured_sha" == "$sha" ]] || fail 'OJDBC17_SHA256 diverge do manifesto'
  [[ "$(sha256sum "$ojdbc_path" | awk '{print $1}')" == "$sha" ]] ||
    fail 'checksum efetivo do ojdbc17 diverge do manifesto'
  [[ -f "$h2_path" ]] || fail 'H2_JAR não aponta para um arquivo existente'
  [[ "$(sha256sum "$h2_path" | awk '{print $1}')" == "$(awk -F '\t' '$1 == "h2" {print $6; exit}' "$MANIFEST")" ]] ||
    fail 'checksum efetivo do H2 diverge do manifesto'
fi

printf 'OK: CP-3H/3.37 módulos Oracle/H2, JNDI, pools, WAR e proveniência validados\n'
