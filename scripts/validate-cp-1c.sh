#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1c.XXXXXXXX")"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1c.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada: %s\n' \
        "$TEMP_DIRECTORY" >&2
      ;;
  esac
}
trap cleanup EXIT

if [[ $# -ne 0 ]]; then
  printf 'Uso: ./scripts/validate-cp-1c.sh\n' >&2
  exit 2
fi

required_paths=(
  "app/pom.xml"
  "app/src/main/java/br/com/asillos/migration/LegacyBuildMarker.java"
  "app/src/main/webapp/WEB-INF/web.xml"
  "docs/legacy-dependencies.md"
  "migration/steps/CP-1C-legacy-build-https.md"
  "runtime/legacy/datasource-contract.properties"
  "runtime/legacy/ojdbc7/README.md"
  "runtime/legacy/ojdbc7/module.xml.template"
  "runtime/legacy/ojdbc7/register-driver.cli"
  "runtime/legacy/war-libraries.txt"
  "scripts/audit-legacy-war.sh"
  "scripts/build-cp-1c.sh"
  "scripts/ValidateApplicationPom.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: arquivo obrigatório ausente: %s\n' "$path" >&2
    exit 1
  fi
done

if git -C "$REPOSITORY_ROOT" ls-files '*.jar' | grep -q .; then
  printf 'FALHA: há JAR versionado no repositório\n' >&2
  exit 1
fi

manual_jar="$(
  find "$REPOSITORY_ROOT/app" \
    -path "$REPOSITORY_ROOT/app/target" -prune -o \
    -type f -name '*.jar' -print -quit
)"
if [[ -n "$manual_jar" ]]; then
  printf 'FALHA: JAR manual encontrado fora de app/target\n' >&2
  exit 1
fi

if ! LC_ALL=C sort -c "$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt"; then
  printf 'FALHA: allowlist de WEB-INF/lib não está ordenada\n' >&2
  exit 1
fi

if [[ "$(
  LC_ALL=C sort "$REPOSITORY_ROOT/runtime/legacy/war-libraries.txt" |
    uniq -d | wc -l | tr -d ' '
)" != "0" ]]; then
  printf 'FALHA: allowlist de WEB-INF/lib contém duplicatas\n' >&2
  exit 1
fi

if ! grep -Fq 'driver-module-name=com.oracle.ojdbc7' \
    "$REPOSITORY_ROOT/runtime/legacy/ojdbc7/register-driver.cli"; then
  printf 'FALHA: CLI não registra o módulo externo aprovado\n' >&2
  exit 1
fi

if grep -Eq \
    'maven\.wagon\.http\.ssl\.(insecure|allowall)=true|http://repo\.maven' \
    "$REPOSITORY_ROOT/scripts/build-cp-1c.sh" \
    "$REPOSITORY_ROOT/app/pom.xml"; then
  printf 'FALHA: configuração Maven insegura detectada\n' >&2
  exit 1
fi

javac -Xlint:-options -source 1.8 -target 1.8 \
  -d "$TEMP_DIRECTORY" \
  "$REPOSITORY_ROOT/scripts/ValidateApplicationPom.java"
java -cp "$TEMP_DIRECTORY" ValidateApplicationPom "$REPOSITORY_ROOT"

printf 'OK: recursos estáticos do CP-1C validados\n'
