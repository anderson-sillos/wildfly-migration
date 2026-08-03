#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    -h|--help)
      printf '%s\n' 'Uso: ./scripts/rebuild-cp-3f-ide.sh [--env ARQUIVO]'
      exit 0
      ;;
    *) printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2; exit 2 ;;
  esac
done

value() {
  local key="$1"
  local exported="${!key:-}"
  if [[ -n "$exported" ]]; then
    printf '%s' "$exported"
  else
    grep -E "^$key=" "$ENV_FILE" | head -1 | cut -d= -f2- |
      sed -e 's/^"//' -e 's/"$//'
  fi
}

JAVA_HOME_VALUE="$(value JAVA21_HOME)"
MAVEN_HOME_VALUE="$(value MAVEN_HOME)"
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$MAVEN_HOME_VALUE/bin/mvn" ]] || {
  printf 'FALHA: JAVA21_HOME e MAVEN_HOME devem apontar para ferramentas completas\n' >&2
  exit 1
}

# Este script é somente para o workspace. O target padrão é intencional:
# o JDT acompanha app/target/generated-sources após a geração do XMLBeans.
# Nenhuma evidência versionada é criada ou atualizada aqui.
JAVA_HOME="$JAVA_HOME_VALUE" \
PATH="$JAVA_HOME_VALUE/bin:$PATH" \
MAVEN_OPTS='-Dhttps.protocols=TLSv1.2' \
  "$MAVEN_HOME_VALUE/bin/mvn" -B -ntp \
  -f "$ROOT/app/pom.xml" \
  -Pci-h2,cp-3e-jakarta11 \
  -Dmigration.build.directory="$ROOT/app/target" \
  clean verify

printf 'OK: rebuild JDT CP-3F concluído em %s/app/target\n' "$ROOT"
