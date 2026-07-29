#!/usr/bin/env bash

set -euo pipefail

LINES=100
TAIL_PID=""

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/follow-wildfly9-log.sh [--lines QUANTIDADE]

Localiza o server.log da única sessão manual ativa do WildFly 9 ou 26 e
acompanha suas últimas linhas até o runtime ser encerrado.
USAGE
}

cleanup() {
  if [[ -n "$TAIL_PID" ]] && kill -0 "$TAIL_PID" >/dev/null 2>&1; then
    kill "$TAIL_PID" >/dev/null 2>&1 || true
    wait "$TAIL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

handle_signal() {
  exit 130
}
trap handle_signal HUP INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lines)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --lines exige uma quantidade\n' >&2
        exit 2
      }
      LINES="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! "$LINES" =~ ^[1-9][0-9]*$ ]]; then
  printf 'FALHA: --lines deve ser um inteiro positivo\n' >&2
  exit 2
fi

SEARCH_ROOT="${TMPDIR:-/tmp}"
log_files=()
shopt -s nullglob
marker_files=(
  "$SEARCH_ROOT"/wildfly-migration-datasource.*/manual-server.pid
)
shopt -u nullglob

for marker_file in "${marker_files[@]}"; do
  server_pid=""
  IFS= read -r server_pid <"$marker_file" || true
  [[ "$server_pid" =~ ^[1-9][0-9]*$ ]] || continue
  kill -0 "$server_pid" >/dev/null 2>&1 || continue

  runtime_directory="${marker_file%/manual-server.pid}"
  log_file="$runtime_directory/server.log"
  process_command_file="/proc/$server_pid/cmdline"
  [[ -f "$log_file" && -r "$process_command_file" ]] || continue

  process_command="$(tr '\0' ' ' <"$process_command_file")"
  case "$process_command" in
    *"$runtime_directory/wildfly-9.0.2.Final"*|\
    *"$runtime_directory/wildfly-26.1.3.Final"*)
      log_files[${#log_files[@]}]="$log_file"
      ;;
  esac
done

case "${#log_files[@]}" in
  0)
    printf 'FALHA: nenhuma sessão manual ativa do WildFly 9 ou 26 foi encontrada\n' \
      >&2
    printf 'Inicie primeiro uma das tasks de aplicação H2 ou Oracle.\n' >&2
    exit 1
    ;;
  1)
    LOG_FILE="${log_files[0]}"
    ;;
  *)
    printf 'FALHA: mais de uma sessão WildFly foi encontrada:\n' >&2
    for log_file in "${log_files[@]}"; do
      printf '  %s\n' "$log_file" >&2
    done
    printf 'Encerre as sessões extras antes de acompanhar o log.\n' >&2
    exit 1
    ;;
esac

printf 'Acompanhando as últimas %s linhas de:\n  %s\n' "$LINES" "$LOG_FILE"
printf 'O acompanhamento termina quando a sessão manual remove o runtime.\n\n'

tail -n "$LINES" -f -- "$LOG_FILE" &
TAIL_PID="$!"

while [[ -f "$LOG_FILE" ]] && kill -0 "$TAIL_PID" >/dev/null 2>&1; do
  sleep 1
done

if [[ ! -f "$LOG_FILE" ]]; then
  printf '\nOK: a sessão manual foi encerrada e o log temporário foi removido\n'
  exit 0
fi

wait "$TAIL_PID"
