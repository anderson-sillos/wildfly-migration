#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAR=""

usage() {
  printf '%s\n' \
    'Uso: ./scripts/validate-cp-3g-discovery.sh [--war ARQUIVO]'
}

fail() {
  printf 'FALHA CP-3G/3.33: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail '--war exige um arquivo'
      WAR="$2"
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

SCI_SOURCE="$ROOT/app/src/main/java/br/com/asillos/migration/integration/validation"
SERVICE="$ROOT/app/src/main/resources/META-INF/services/jakarta.servlet.ServletContainerInitializer"
for path in \
  "$SCI_SOURCE/Validator.java" \
  "$SCI_SOURCE/PedidoImportValidator.java" \
  "$SCI_SOURCE/ValidatorDiscovery.java" \
  "$SCI_SOURCE/ValidatorServletContainerInitializer.java" \
  "$SERVICE" \
  "$ROOT/migration/steps/CP-3G-servlet-container-initializer.md"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

grep -Fq '@HandlesTypes(Validator.class)' \
  "$SCI_SOURCE/ValidatorServletContainerInitializer.java" ||
  fail 'SCI não declara @HandlesTypes(Validator.class)'
grep -Fq 'ValidatorDiscovery.initialize(context, classes)' \
  "$SCI_SOURCE/ValidatorServletContainerInitializer.java" ||
  fail 'SCI não delega para a fachada própria'
grep -Fqx \
  'br.com.asillos.migration.integration.validation.ValidatorServletContainerInitializer' \
  "$SERVICE" || fail 'descritor de serviço aponta para classe inesperada'
grep -Fq 'context.setAttribute(' "$SCI_SOURCE/ValidatorDiscovery.java" ||
  fail 'fachada não registra o conjunto por ServletContext'
grep -Fq 'type.isAnnotationPresent(Validator.class)' \
  "$SCI_SOURCE/ValidatorDiscovery.java" ||
  fail 'fachada não verifica a annotation Validator'
grep -Fq 'type.isInterface()' "$SCI_SOURCE/ValidatorDiscovery.java" ||
  fail 'fachada não rejeita interfaces'
grep -Fq 'Modifier.isAbstract(type.getModifiers())' \
  "$SCI_SOURCE/ValidatorDiscovery.java" ||
  fail 'fachada não rejeita classes abstratas'
grep -Fq 'Collections.sort(' "$SCI_SOURCE/ValidatorDiscovery.java" ||
  fail 'fachada não ordena os validadores'
if grep -REn 'org\.reflections|LegacyValidatorDiscovery' \
    "$ROOT/app/src/main/java"; then
  fail 'Reflections ou a fachada legada permanecem no código ativo'
fi
if grep -Fq '<artifactId>reflections</artifactId>' "$ROOT/app/pom.xml"; then
  fail 'POM ainda declara Reflections'
fi

if [[ -n "$WAR" ]]; then
  [[ -f "$WAR" ]] || fail "WAR não encontrado: $WAR"
  entries="$(mktemp)"
  nested="$(mktemp)"
  cleanup() {
    rm -f -- "$entries" "$nested"
  }
  trap cleanup EXIT
  jar tf "$WAR" >"$entries"
  grep -Fxq 'WEB-INF/lib/wildfly-migration-validator-sci.jar' "$entries" ||
    fail 'WAR não contém o JAR interno do SCI'
  if grep -Eq \
      '^WEB-INF/classes/br/com/asillos/migration/integration/validation/(Validator|PedidoImportValidator|ValidatorDiscovery(\$[^/]*)?|ValidatorServletContainerInitializer(\$[^/]*)?)\.class$' \
      "$entries"; then
    fail 'infraestrutura SCI foi duplicada em WEB-INF/classes'
  fi
  if grep -Fq \
      'WEB-INF/classes/META-INF/services/jakarta.servlet.ServletContainerInitializer' \
      "$entries"; then
    fail 'descritor SCI foi duplicado em WEB-INF/classes'
  fi
  for validator in \
    NumeroFormatoValidator \
    ValorMonetarioValidator \
    StatusInicialValidator; do
    grep -Fxq \
      "WEB-INF/classes/br/com/asillos/migration/integration/validation/${validator}.class" \
      "$entries" || fail "validator de WEB-INF/classes ausente: $validator"
  done
  unzip -p "$WAR" WEB-INF/lib/wildfly-migration-validator-sci.jar >"$nested" ||
    fail 'não foi possível extrair o JAR interno do SCI'
  nested_entries="$(mktemp)"
  trap 'rm -f -- "$entries" "$nested" "$nested_entries"' EXIT
  jar tf "$nested" >"$nested_entries"
  for entry in \
    br/com/asillos/migration/integration/validation/Validator.class \
    br/com/asillos/migration/integration/validation/PedidoImportValidator.class \
    br/com/asillos/migration/integration/validation/ValidatorDiscovery.class \
    br/com/asillos/migration/integration/validation/ValidatorServletContainerInitializer.class \
    META-INF/services/jakarta.servlet.ServletContainerInitializer; do
    grep -Fxq "$entry" "$nested_entries" ||
      fail "JAR interno do SCI não contém: $entry"
  done
fi

printf 'OK: CP-3G/3.33 substitui Reflections pelo SCI padrão e audita o JAR interno\n'
