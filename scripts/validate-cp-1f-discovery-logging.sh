#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1f-discovery.XXXXXXXX"
)"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1f-discovery.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

required_paths=(
  "app/src/main/java/br/com/asillos/migration/integration/validation/PedidoImportValidator.java"
  "app/src/main/java/br/com/asillos/migration/integration/validation/LegacyValidatorDiscovery.java"
  "app/src/main/java/br/com/asillos/migration/integration/validation/NumeroFormatoValidator.java"
  "app/src/main/java/br/com/asillos/migration/integration/validation/ValorMonetarioValidator.java"
  "app/src/main/java/br/com/asillos/migration/integration/validation/StatusInicialValidator.java"
  "app/src/main/java/br/com/asillos/migration/integration/validation/PedidoImportValidationException.java"
  "app/src/main/resources/log4j.properties"
  "docs/legacy-validation-logging.md"
  "scripts/ValidateLegacyDiscoveryLogging.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: recurso Reflections/Log4j ausente: %s\n' "$path" >&2
    exit 1
  fi
done

install -d -m 0755 "$TEMP_DIRECTORY/classes"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyDiscoveryLogging.java"
java -cp "$TEMP_DIRECTORY/classes" \
  ValidateLegacyDiscoveryLogging "$REPOSITORY_ROOT"

if grep -REiq \
    'jdbc:(oracle|h2):|ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=' \
    "$REPOSITORY_ROOT/app/src/main/java/br/com/asillos/migration/integration/validation" \
    "$REPOSITORY_ROOT/app/src/main/resources/log4j.properties" \
    "$REPOSITORY_ROOT/docs/legacy-validation-logging.md"; then
  printf 'FALHA: endpoint ou credencial foi incluído no logging\n' >&2
  exit 1
fi

printf 'OK: descoberta e logging não contêm endpoint ou segredo embutido\n'
