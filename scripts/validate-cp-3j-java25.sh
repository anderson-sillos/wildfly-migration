#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POM="$ROOT/app/pom.xml"
BUILD="$ROOT/scripts/build-cp-3j-java25.sh"
SMOKE="$ROOT/scripts/smoke-wildfly41-datasource.sh"
WORKFLOW="$ROOT/.github/workflows/validate.yml"
MANIFEST="$ROOT/runtime/phase3/java25-wildfly41/runtime-manifest.tsv"
RESULT="$ROOT/migration/evidence/CP-3J/java25-build.json"
EXPECTED="$ROOT/migration/evidence/CP-3J/java25-build-expected.properties"

fail() {
  printf 'FALHA CP-3J/3.47: %s\n' "$1" >&2
  exit 1
}

for path in "$POM" "$BUILD" "$SMOKE" "$WORKFLOW" "$MANIFEST" "$EXPECTED"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for marker in \
  '<id>cp-3e-jakarta11</id>' \
  '<jdk>[21,22)</jdk>' \
  '<maven.compiler.source>21</maven.compiler.source>' \
  '<maven.compiler.target>21</maven.compiler.target>' \
  '<java.version.range>[21,22)</java.version.range>'; do
  grep -Fq "$marker" "$POM" || fail "perfil Java 25 sem: $marker"
done

for marker in \
  'JAVA25_HOME' \
  'cp-3e-jakarta11' \
  'cp3j-java25' \
  'buildOutcome' \
  'bytecodeTarget'; do
  grep -Fq "$marker" "$BUILD" || fail "build Java 25 sem: $marker"
done

for marker in \
  '--java 21|25' \
  'JAVA25_HOME' \
  'RUNTIME_LABEL="java25-wildfly41.0.0"' \
  'runtime/phase3/$RUNTIME_MANIFEST_DIR/runtime-manifest.tsv'; do
  grep -Fq -- "$marker" "$SMOKE" || fail "smoke parametrizado sem: $marker"
done

for marker in \
  'tar -xzf OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz' \
  'JAVA25_HOME=$tools/jdk-25.0.4+7' \
  'build-cp-3j-java25.sh'; do
  grep -Fq -- "$marker" "$WORKFLOW" || fail "workflow Java 25 sem: $marker"
done

grep -Fq $'temurin-openjdk\t25.0.4+7' "$MANIFEST" ||
  fail 'manifesto Java 25 não está fixado'

for marker in \
  'build.result=failed-expected' \
  'failure.category=javac-source-target-system-modules-warning' \
  'failure.cause=-Werror-promotes-jdk25-warning-to-error' \
  'functional.smoke=not-executed' \
  'next.activity=3.48' \
  'result=passed'; do
  grep -Fxq "$marker" "$EXPECTED" || fail "evidência esperada sem: $marker"
done

if [[ -f "$RESULT" ]]; then
  for marker in \
    '"activity": "3.47"' \
    '"profile": "cp-3e-jakarta11"' \
    '"javaVersionRangeOverride": "[25,26)"' \
    '"runtime": "Temurin 25.0.4+7/Maven 3.9.16"' \
    '"buildOutcome": "failed"' \
    '"exitCode": 1' \
    '"compilationErrorBlocks": 1'; do
    grep -Fq "$marker" "$RESULT" || fail "resultado Java 25 sem: $marker"
  done
fi

if [[ -f "$ROOT/migration/evidence/CP-3J/java25-build.txt" ]]; then
  grep -Fq 'location of system modules is not set in conjunction with -source 21' \
    "$ROOT/migration/evidence/CP-3J/java25-build.txt" ||
    fail 'saída Java 25 não registra o aviso de módulos esperado'
  grep -Fq 'warnings found and -Werror specified' \
    "$ROOT/migration/evidence/CP-3J/java25-build.txt" ||
    fail 'saída Java 25 não registra a promoção do aviso por -Werror'
fi

printf 'OK: CP-3J/3.47 registrou a incompatibilidade esperada do javac 25 sem alterar Jakarta/bytecode 21\n'
