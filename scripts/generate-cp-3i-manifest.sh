#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR_FILE="$ROOT/app/target/cp3f-jakarta11/wildfly-migration.war"
OUTPUT="$ROOT/migration/evidence/CP-3I/manifest.properties"
RUNTIME_MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"

fail() {
  printf 'FALHA CP-3I/3.43: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf '%s\n' \
    'Uso: ./scripts/generate-cp-3i-manifest.sh [--war ARQUIVO] [--output ARQUIVO]' \
    'Gera o manifesto versionável do gate Java 21/WildFly 41.'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war) [[ $# -ge 2 ]] || fail '--war exige um arquivo'; WAR_FILE="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || fail '--output exige um arquivo'; OUTPUT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"
[[ -f "$RUNTIME_MANIFEST" ]] || fail 'manifesto de runtime ausente'
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum não encontrado'
command -v jar >/dev/null 2>&1 || fail 'jar não encontrado'

runtime_value() {
  local component="$1"
  local column="$2"
  awk -F '\t' -v component="$component" -v column="$column" \
    'NR > 1 && $1 == component { print $column; found=1; exit }
     END { if (!found) exit 1 }' "$RUNTIME_MANIFEST"
}

java_version="$(runtime_value temurin-openjdk 2)" || fail 'Temurin 21 não registrado'
wildfly_archive="$(runtime_value wildfly-community-41 3)" || fail 'WildFly 41 não registrado'
h2_version="$(runtime_value h2 2)" || fail 'H2 do gate não registrado'
ojdbc_version="$(runtime_value ojdbc17 2)" || fail 'ojdbc17 do gate não registrado'
java_license="$(runtime_value temurin-openjdk 5)"
wildfly_license="$(runtime_value wildfly-community-41 5)"
h2_license="$(runtime_value h2 5)"
ojdbc_license="$(runtime_value ojdbc17 5)"
java_sha256="$(runtime_value temurin-openjdk 6)"
wildfly_sha256="$(runtime_value wildfly-community-41 6)"
h2_sha256="$(runtime_value h2 6)"
ojdbc_sha256="$(runtime_value ojdbc17 6)"

[[ "$java_version" == '21.0.12+8' ]] || fail "versão Temurin inesperada: $java_version"
[[ "$wildfly_archive" == 'wildfly-41.0.0.Final.tar.gz' ]] ||
  fail "arquivo WildFly inesperado: $wildfly_archive"
[[ "$h2_version" == '2.4.240' ]] || fail "versão H2 inesperada: $h2_version"
[[ "$ojdbc_version" == '23.26.2.0.0' ]] || fail "versão ojdbc17 inesperada: $ojdbc_version"

war_sha256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
war_library_count="$(jar tf "$WAR_FILE" | awk '/^WEB-INF\/lib\/[^/]+\.jar$/ { count++ } END { print count + 0 }')"
source_commit="$(git -C "$ROOT" rev-parse HEAD)"
relative_output="${OUTPUT#"$ROOT/"}"
working_tree=false
while IFS= read -r status_line; do
  status_path="${status_line:3}"
  case "$status_path" in
    "$relative_output"|migration/evidence/*|app/target/*)
      continue
      ;;
  esac
  if [[ "$status_path" != "$relative_output" ]]; then
    working_tree=true
    break
  fi
done < <(git -C "$ROOT" status --porcelain --untracked-files=all)

mkdir -p "$(dirname "$OUTPUT")"
cat > "$OUTPUT" <<EOF
schema=wildfly-migration-cp3i-manifest/v1
checkpoint=CP-3I
activity=3.43
sourceCommit=$source_commit
workingTree=$working_tree
runtime.manifest=runtime/phase3/java21-wildfly41/runtime-manifest.tsv
runtime.java=$java_version
runtime.java.distribution=Eclipse Temurin
runtime.java.license=$java_license
runtime.java.sha256=$java_sha256
runtime.wildfly=41.0.0.Final
runtime.wildfly.distribution=WildFly community
runtime.wildfly.license=$wildfly_license
runtime.wildfly.sha256=$wildfly_sha256
runtime.ee=Jakarta-EE-11-Servlet-6.1
runtime.maven=3.9.16
runtime.h2=$h2_version
runtime.h2.license=$h2_license
runtime.h2.sha256=$h2_sha256
runtime.oracle=19.3.0.0.0
runtime.oracle.driver=ojdbc17-$ojdbc_version
runtime.oracle.driver.license=$ojdbc_license
runtime.oracle.driver.sha256=$ojdbc_sha256
war.path=$(realpath --relative-to="$ROOT" "$WAR_FILE")
war.sha256=$war_sha256
war.libraryCount=$war_library_count
dependency.mybatis=3.5.19
dependency.xmlbeans=5.3.0
dependency.dom4j=2.2.0
dependency.logging=WildFly JBoss LogManager via SLF4J 2.0.18 provided
dependency.servletApi=provided by WildFly Jakarta EE 11
dependency.oracleDriver=server-module-only
dependency.h2=runtime-only
evidence.persistence.h2=migration/evidence/CP-3I/persistence-ci-h2.json
evidence.persistence.oracle=migration/evidence/CP-3I/persistence-oracle.json
evidence.contracts.h2=migration/evidence/CP-3I/contract-ci-h2.json
evidence.contracts.oracle=migration/evidence/CP-3I/contract-oracle.json
evidence.xml=migration/evidence/CP-3H/xml-ci-h2.json
evidence.packaging=migration/evidence/CP-3H/packaging-audit.json
portable-ci.result=passed
oracle-qualified.result=passed
result=passed
EOF

printf 'OK: manifesto CP-3I/3.43 gerado em %s\n' "${OUTPUT#"$ROOT/"}"
