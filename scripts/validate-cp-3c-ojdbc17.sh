#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3c-ojdbc17.sh [--env ARQUIVO]

Valida o contrato estático do ojdbc17 no gate Java 17: manifesto, checksum,
módulo WildFly, perfil Oracle, fornecimento externo e isolamento do WAR. O
driver fica fora do cache portátil do CI. A qualificação que acessa Oracle 19c
é executada separadamente por
qualify-cp-3c-oracle.sh.
USAGE
}

fail() {
  printf 'FALHA CP-3C ojdbc17: %s\n' "$1" >&2
  exit 1
}

read_env_value() {
  local wanted_key="$1"
  local file="$2"
  awk -F= -v wanted="$wanted_key" '
    $1 == wanted {
      value = substr($0, index($0, "=") + 1)
      sub(/^"/, "", value); sub(/"$/, "", value)
      sub(/^'"'"'/, "", value); sub(/'"'"'$/, "", value)
      print value
      found++
    }
    END { if (found != 1) exit 1 }
  ' "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"
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

MANIFEST="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/runtime-manifest.tsv"
PROFILE="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/profiles/oracle.cli"
MODULE="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/ojdbc17/module.xml.template"
REGISTER="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/ojdbc17/register-driver.cli"
LOCK="$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
SOURCES="$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv"
WAR="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
EXPECTED_SHA="96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb"

for path in "$MANIFEST" "$PROFILE" "$MODULE" "$REGISTER" "$LOCK" "$SOURCES"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#$REPOSITORY_ROOT/}"
done

manifest_row="$(awk -F '\t' '$1 == "ojdbc17" { print; found=1; exit } END { if (!found) exit 1 }' "$MANIFEST")" ||
  fail "ojdbc17 não está no manifesto do runtime Java 17"
IFS=$'\t' read -r component version archive origin license sha published lifecycle scope <<< "$manifest_row"
[[ "$version" == "23.26.2.0.0" && "$archive" == "ojdbc17.jar" ]] ||
  fail "versão ou nome do ojdbc17 diverge do manifesto"
[[ "$origin" == "https://repo.maven.apache.org/maven2/com/oracle/database/jdbc/ojdbc17/23.26.2.0.0/ojdbc17-23.26.2.0.0.jar" ]] ||
  fail "origem do ojdbc17 diverge do Maven Central fixado"
[[ "$license" == "Oracle Free Use Terms and Conditions (FUTC)" ]] ||
  fail "licença FUTC não registrada para o ojdbc17"
[[ "$sha" == "$EXPECTED_SHA" && "$published" == "sha256:$EXPECTED_SHA" ]] ||
  fail "checksum do ojdbc17 diverge do valor publicado"

if grep -Fq 'ojdbc17' "$LOCK" || grep -Fq 'ojdbc17' "$SOURCES"; then
  fail "ojdbc17 não deve ser incluído no cache portátil do CI"
fi

grep -Fq 'driver-module-name=com.oracle.ojdbc17' "$PROFILE" ||
  fail "perfil Oracle Java 17 não registra com.oracle.ojdbc17"
grep -Fq 'name="com.oracle.ojdbc17"' "$MODULE" ||
  fail "module.xml não declara com.oracle.ojdbc17"
grep -Fq 'resource-root path="ojdbc17.jar"' "$MODULE" ||
  fail "module.xml não referencia ojdbc17.jar"
grep -Fq 'driver-module-name=com.oracle.ojdbc17' "$REGISTER" ||
  fail "register-driver.cli não registra ojdbc17"
if grep -Fq 'ojdbc7' "$PROFILE" || grep -Fq 'ojdbc7' "$MODULE"; then
  fail "artefato legado ojdbc7 ainda aparece no runtime Java 17"
fi

[[ -f "$ENV_FILE" ]] || fail ".env não encontrado: configure o ambiente externo"
driver="$(read_env_value OJDBC17_JAR "$ENV_FILE" || true)"
configured_sha="$(read_env_value OJDBC17_SHA256 "$ENV_FILE" || true)"
[[ -f "$driver" ]] || fail "OJDBC17_JAR não aponta para um arquivo existente"
[[ "$(basename "$driver")" == "ojdbc17.jar" ]] || fail "OJDBC17_JAR deve terminar em ojdbc17.jar"
[[ "$configured_sha" == "$EXPECTED_SHA" ]] || fail "OJDBC17_SHA256 diverge do manifesto"
[[ "$(sha256sum "$driver" | awk '{print $1}')" == "$EXPECTED_SHA" ]] ||
  fail "SHA-256 efetivo do ojdbc17 diverge"

if [[ -f "$WAR" ]]; then
  if unzip -Z1 "$WAR" | grep -Eiq '(^|/)ojdbc(7|8|10|11|17)?[^/]*\.jar$'; then
    fail "WAR empacota driver Oracle; o módulo deve permanecer externo"
  fi
fi

printf 'OK: contrato CP-3C ojdbc17, fornecimento externo e exclusão do cache portátil validados\n'
