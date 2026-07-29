#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1f-contracts.XXXXXXXX"
)"

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1f-contracts.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

required_paths=(
  "contract-tests/run.sh"
  "contract-tests/README.md"
  "contract-tests/fixtures/xml/pedido-valido.xml"
  "contract-tests/fixtures/xml/pedido-invalido-xsd.xml"
  "contract-tests/fixtures/xml/pedido-invalido-validador.xml"
  "contract-tests/fixtures/xml/pedido-xxe.xml"
  "contract-tests/fixtures/xml/pedido-entidades-expansivas.xml"
  "scripts/ValidateExternalContracts.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: recurso da suíte externa ausente: %s\n' "$path" >&2
    exit 1
  fi
done

bash -n "$REPOSITORY_ROOT/contract-tests/run.sh"
install -d -m 0755 "$TEMP_DIRECTORY/classes"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateExternalContracts.java"
java -cp "$TEMP_DIRECTORY/classes" \
  ValidateExternalContracts "$REPOSITORY_ROOT"

if grep -Eiq \
    'ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=|WEB-INF/classes|app/target/classes|br\.com\.asillos' \
    "$REPOSITORY_ROOT/contract-tests/run.sh"; then
  printf 'FALHA: suíte externa atravessou a fronteira ou contém segredo\n' >&2
  exit 1
fi

printf 'OK: suíte externa preserva a fronteira HTTP e não contém segredo\n'
