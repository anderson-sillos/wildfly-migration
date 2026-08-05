#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/runtime/phase3/java25-wildfly41/runtime-manifest.tsv"
README="$ROOT/runtime/phase3/java25-wildfly41/README.md"
EVIDENCE="$ROOT/migration/evidence/CP-3J/runtime-selection.properties"
DOC="$ROOT/docs/evidence/CP-3J.md"
SOURCES="$ROOT/runtime/portable-runtime-sources.tsv"
CACHE="$ROOT/runtime/portable-runtime-cache.sha256"

fail() {
  printf 'FALHA CP-3J/3.46: %s\n' "$1" >&2
  exit 1
}

for path in "$MANIFEST" "$README" "$EVIDENCE" "$DOC" "$SOURCES" "$CACHE"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for row in \
  $'temurin-openjdk\t25.0.4+7\tOpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz' \
  $'wildfly-community-41\t41.0.0.Final\twildfly-41.0.0.Final.tar.gz' \
  $'h2\t2.4.240\th2-2.4.240.jar' \
  $'ojdbc17\t23.26.2.0.0\tojdbc17.jar'; do
  grep -Fq "$row" "$MANIFEST" || fail "componente ausente ou divergente: $row"
done

for marker in \
  'GPL-2.0-only WITH Classpath-exception-2.0' \
  'LGPL-2.1-or-later' \
  'MPL-2.0 OR EPL-1.0' \
  'Oracle Free Use Terms and Conditions (FUTC)' \
  'e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94' \
  'd240795958e7d99b638cd4c3e0f9ba4b7d4c53b4f7996dfec1008250c4d48191' \
  '29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0'; do
  grep -Fq "$marker" "$MANIFEST" || fail "proveniência/checksum ausente: $marker"
done

for archive in \
  'OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz' \
  'wildfly-41.0.0.Final.tar.gz' \
  'h2-2.4.240.jar'; do
  grep -Fq "$archive" "$SOURCES" || fail "origem de cache ausente: $archive"
  grep -Fq "$archive" "$CACHE" || fail "checksum de cache ausente: $archive"
done

for marker in \
  'selected.java=Eclipse-Temurin-OpenJDK-25.0.4+7' \
  'selected.wildfly=WildFly-Community-41.0.0.Final' \
  'selected.h2=2.4.240' \
  'oracle.jdk=rejected' \
  'jboss.eap=rejected' \
  'wildfly.preview=rejected' \
  'nightly.builds=rejected' \
  'selection.result=passed'; do
  grep -Fxq "$marker" "$EVIDENCE" || fail "decisão não contém: $marker"
done

for marker in \
  'Temurin OpenJDK 25.0.4+7' \
  'WildFly Community 41.0.0.Final' \
  'H2 2.4.240' \
  'não será incluído no WAR' \
  'rejeita Oracle JDK, JBoss EAP, WildFly Preview e builds nightly' \
  'runtime/portable-runtime-sources.tsv' \
  'https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4%2B7' \
  'https://www.wildfly.org/downloads/' \
  'https://github.com/h2database/h2database/releases/tag/version-2.4.240'; do
  grep -Fq "$marker" "$README" || fail "documentação sem: $marker"
done

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=' \
    "$MANIFEST" "$README" "$EVIDENCE" "$DOC"; then
  fail 'seleção de runtime contém configuração sensível'
fi
if grep -Eiq 'jboss-eap|oracle-jdk|wildfly-preview|nightly' "$MANIFEST"; then
  fail 'manifesto seleciona distribuição rejeitada'
fi

for marker in \
  'Eclipse Temurin OpenJDK 25.0.4+7' \
  'WildFly Community 41.0.0.Final' \
  'H2 2.4.240' \
  'A certificação Jakarta EE 11 publicada cobre Java SE 17 e' \
  'Oracle JDK, JBoss EAP, WildFly Preview e builds nightly foram rejeitados'; do
  grep -Fq "$marker" "$DOC" || fail "evidência consolidada sem: $marker"
done

printf 'OK: CP-3J/3.46 OpenJDK 25, WildFly 41 e H2 selecionados com origem, licença, checksums e rejeições registradas\n'
