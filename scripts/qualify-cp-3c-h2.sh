#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
RESULT_DIRECTORY="$REPOSITORY_ROOT/app/target/contract-results"
NON_INTERACTIVE=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/qualify-cp-3c-h2.sh [--env ARQUIVO] [--result-directory DIRETORIO]
    [--non-interactive]

Executa a trilha portátil do CP-3C: doctor, build Java 17, XMLBeans/java.xml,
persistência MyBatis no H2 e smoke do datasource. O resultado é portable-ci.
USAGE
}

fail() {
  printf 'FALHA qualificação H2 CP-3C: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"; shift 2
      ;;
    --result-directory)
      [[ $# -ge 2 ]] || fail "--result-directory exige um diretório"
      RESULT_DIRECTORY="$2"; shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE=true; shift
      ;;
    -h|--help)
      usage; exit 0
      ;;
    *) fail "argumento desconhecido: $1" ;;
  esac
done

WAR="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
mkdir -p "$RESULT_DIRECTORY"
doctor_args=(CP-3C --profile ci-h2 --env "$ENV_FILE")
if [[ "$NON_INTERACTIVE" == true ]]; then
  doctor_args+=(--non-interactive)
fi
"$REPOSITORY_ROOT/scripts/doctor.sh" "${doctor_args[@]}"
"$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
  --profile ci-h2 --env "$ENV_FILE" --ide-rebuild
"$REPOSITORY_ROOT/scripts/validate-cp-3c-ojdbc17.sh" --env "$ENV_FILE"
"$REPOSITORY_ROOT/scripts/validate-cp-3c-xmlbeans.sh" \
  --env "$ENV_FILE" --war "$WAR" --skip-build \
  --classes-directory "$REPOSITORY_ROOT/app/target/vscode-build/classes" \
  --generated-sources-directory \
  "$REPOSITORY_ROOT/app/target/vscode-build/generated-sources"
"$REPOSITORY_ROOT/scripts/validate-cp-3c-java-xml.sh" \
  --env "$ENV_FILE" --war "$WAR" --skip-build \
  --classes-directory "$REPOSITORY_ROOT/app/target/vscode-build/classes"
"$REPOSITORY_ROOT/scripts/validate-cp-1e-persistence.sh" \
  --java-home "${JAVA17_HOME:-/opt/migration-lab/tools/jdk-17.0.20+8}" \
  --h2-jar "${H2_JAR:-/opt/migration-lab/archives/h2-2.4.240.jar}" \
  --war "$WAR" --result "$RESULT_DIRECTORY/cp-3c-mybatis-ci-h2.json"
"$REPOSITORY_ROOT/scripts/smoke-cp-3b-datasource.sh" \
  --profile ci-h2 --env "$ENV_FILE" --war "$WAR" \
  --contract-result "$RESULT_DIRECTORY/cp-3c-contract-ci-h2.json"

printf 'OK: qualificação H2 CP-3C concluída; relatórios em %s\n' \
  "$RESULT_DIRECTORY"
