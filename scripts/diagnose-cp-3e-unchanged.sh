#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE=""
RESULT_FILE=""
DIAGNOSTIC_LOG_FILE=""
HTTP_PORT="18180"
MANAGEMENT_PORT="19991"
TEMP_DIRECTORY=""
SERVER_PID=""
RUNTIME_HOME=""
JAVA_HOME_VALUE=""

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/diagnose-cp-3e-unchanged.sh --war ARQUIVO \
    --result ARQUIVO --diagnostic-log ARQUIVO [--env ARQUIVO]

Tenta implantar o WAR aprovado no CP-3D no WildFly 41 com Java 21, sem
alterar código ou descritores. O resultado e o log sanitizado são preservados
como diagnóstico de entrada do CP-3E.
USAGE
}

configuration_value() {
  local key="$1"
  local value
  value="$(grep -E "^$key=" "$ENV_FILE" | head -1 | cut -d= -f2- || true)"
  value="$(printf '%s' "$value" | sed -e 's/^"//' -e 's/"$//')"
  printf '%s' "$value"
}

sanitize_log() {
  sed -E \
    -e "s#$TEMP_DIRECTORY#<runtime-temporario>#g" \
    -e 's#(/opt/migration-lab/(archives|tools)/)[^[:space:]]+#\1<runtime>#g' \
    -e $'s/\x1B\\[[0-9;]*[[:alpha:]]//g'
}

cleanup() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT" --commands=':shutdown' \
      >/dev/null 2>&1 || true
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$DIAGNOSTIC_LOG_FILE" && -f "$TEMP_DIRECTORY/server.log" ]]; then
    install -d -m 0755 "$(dirname "$DIAGNOSTIC_LOG_FILE")"
    sanitize_log <"$TEMP_DIRECTORY/server.log" >"$DIAGNOSTIC_LOG_FILE"
  fi
  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      /tmp/wildfly-migration-cp3e.*) rm -rf -- "$TEMP_DIRECTORY" ;;
      *) printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2 ;;
    esac
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --war) WAR_FILE="$2"; shift 2 ;;
    --result) RESULT_FILE="$2"; shift 2 ;;
    --diagnostic-log) DIAGNOSTIC_LOG_FILE="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --management-port) MANAGEMENT_PORT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$WAR_FILE" ]] || { printf 'FALHA: WAR do CP-3D não encontrado\n' >&2; exit 1; }
[[ -n "$RESULT_FILE" && -n "$DIAGNOSTIC_LOG_FILE" ]] || {
  printf 'FALHA: --result e --diagnostic-log são obrigatórios\n' >&2
  exit 2
}

JAVA_HOME_VALUE="$(configuration_value JAVA21_HOME)"
JAVA_ARCHIVE_VALUE="$(configuration_value JAVA21_ARCHIVE)"
WILDFLY_HOME_VALUE="$(configuration_value WILDFLY41_HOME)"
WILDFLY_ARCHIVE_VALUE="$(configuration_value WILDFLY41_ARCHIVE)"

for required in \
  "$JAVA_HOME_VALUE/bin/java" "$WILDFLY_HOME_VALUE/bin/standalone.sh" \
  "$WILDFLY_HOME_VALUE/bin/jboss-cli.sh" "$JAVA_ARCHIVE_VALUE" "$WILDFLY_ARCHIVE_VALUE"; do
  [[ -e "$required" ]] || { printf 'FALHA: recurso CP-3E ausente: %s\n' "$required" >&2; exit 1; }
done

expected_java_sha256="$(awk '$2 == "OpenJDK21U-jdk_x64_linux_hotspot_21.0.12_8.tar.gz" {print $1; exit}' \
  "$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256")"
expected_wildfly_sha256="$(awk -F '\t' '$1 == "wildfly-community-41" {print $6; exit}' \
  "$REPOSITORY_ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv")"
actual_java_sha256="$(sha256sum "$JAVA_ARCHIVE_VALUE" | awk '{print $1}')"
actual_wildfly_sha256="$(sha256sum "$WILDFLY_ARCHIVE_VALUE" | awk '{print $1}')"
[[ "$actual_java_sha256" == "$expected_java_sha256" ]] || { printf 'FALHA: checksum Java 21 divergente\n' >&2; exit 1; }
[[ "$actual_wildfly_sha256" == "$expected_wildfly_sha256" ]] || { printf 'FALHA: checksum WildFly 41 divergente\n' >&2; exit 1; }

java_version="$("$JAVA_HOME_VALUE/bin/java" -version 2>&1)"
[[ "$java_version" == *'openjdk version "21.0.12"'* && "$java_version" == *'Temurin-21.0.12+8'* ]] || {
  printf 'FALHA: Temurin 21.0.12+8 não foi detectado\n' >&2
  exit 1
}

WAR_FILE="$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")"
WAR_SHA256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3e.XXXXXXXX)"
RUNTIME_HOME="$TEMP_DIRECTORY/wildfly-41.0.0.Final"
cp -a "$WILDFLY_HOME_VALUE/." "$RUNTIME_HOME/"
mkdir -p "$RUNTIME_HOME/standalone/log"

JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/standalone.sh" \
  -b 127.0.0.1 -bmanagement 127.0.0.1 \
  -Djboss.http.port="$HTTP_PORT" \
  -Djboss.management.http.port="$MANAGEMENT_PORT" \
  >"$TEMP_DIRECTORY/server.log" 2>&1 &
SERVER_PID="$!"

ready=false
for unused in $(seq 1 90); do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then break; fi
  if JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT" \
      --commands=':read-attribute(name=server-state)' >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
done
[[ "$ready" == true ]] || { printf 'FALHA: WildFly 41 não iniciou\n' >&2; exit 1; }

deploy_status="accepted"
if ! JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT" \
    --commands="deploy $WAR_FILE --force" >"$TEMP_DIRECTORY/deploy.out" 2>&1; then
  deploy_status="rejected"
fi

deployment_state="not-readable"
if deployment_json="$(JAVA_HOME="$JAVA_HOME_VALUE" "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT" \
    --commands='/deployment=wildfly-migration.war:read-attribute(name=status)' 2>/dev/null)"; then
  deployment_state="$(printf '%s\n' "$deployment_json" | sed -n 's/.*=> \([^,]*\).*/\1/p' | head -1)"
  [[ -n "$deployment_state" ]] || deployment_state="read-without-value"
fi
if [[ "$deploy_status" == accepted && "$deployment_state" == *FAILED* ]]; then
  deploy_status="accepted-but-failed"
fi

install -d -m 0755 "$(dirname "$RESULT_FILE")"
cat >"$RESULT_FILE" <<EOF
{
  "schema": "wildfly-migration-cp3e-entry/v1",
  "checkpoint": "CP-3E",
  "sourceCheckpoint": "CP-3D",
  "runtime": "java21-wildfly41.0.0",
  "java": "Temurin 21.0.12+8",
  "wildfly": "41.0.0.Final",
  "warSha256": "$WAR_SHA256",
  "deploymentCommand": "unchanged WAR; no source or descriptor transformation",
  "deploymentCommandStatus": "$deploy_status",
  "deploymentStatus": "$deployment_state",
  "checks": {
    "runtimeStarted": "passed",
    "unchangedWarAttempted": "passed",
    "compatibilityOutcomeCaptured": "passed"
  }
}
EOF

printf 'CP-3E: tentativa concluída (%s); diagnóstico em %s\n' "$deploy_status" "$DIAGNOSTIC_LOG_FILE"
