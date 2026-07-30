#!/usr/bin/env bash

set -euo pipefail

BASE_REF=""
HEAD_REF=""
OUTPUT_FILE=""
declare -a CHANGED_FILES=()

fail() {
  printf 'FALHA: %s\n' "$1" >&2
  exit 1
}

record_output() {
  local key="$1"
  local value="$2"

  if [[ -n "$OUTPUT_FILE" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$OUTPUT_FILE"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ $# -ge 2 ]] || fail "--base exige uma referência Git"
      BASE_REF="$2"
      shift 2
      ;;
    --head)
      [[ $# -ge 2 ]] || fail "--head exige uma referência Git"
      HEAD_REF="$2"
      shift 2
      ;;
    --changed-file)
      [[ $# -ge 2 ]] || fail "--changed-file exige um caminho"
      CHANGED_FILES+=("$2")
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || fail "--output exige um arquivo"
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      printf '%s\n' \
        'Uso: ./scripts/detect-portable-change.sh --base REF --head REF [--output ARQUIVO]' \
        '   ou ./scripts/detect-portable-change.sh --changed-file CAMINHO [...]'
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  [[ -n "$BASE_REF" ]] || fail "--base é obrigatório sem --changed-file"
  [[ -n "$HEAD_REF" ]] || fail "--head é obrigatório sem --changed-file"

  if ! git cat-file -e "${BASE_REF}^{commit}" 2>/dev/null ||
     ! git cat-file -e "${HEAD_REF}^{commit}" 2>/dev/null; then
    printf '%s\n' \
      "Referência não disponível localmente; executar portable-ci por segurança."
    record_output "runtime_changed" "true"
    record_output "selection_reason" "git-reference-unavailable"
    exit 0
  fi

  mapfile -t CHANGED_FILES < <(
    git diff --name-only --diff-filter=ACMRTD "$BASE_REF" "$HEAD_REF" --
  )
fi

runtime_changed=false
selection_reason="documentation-or-planning-only"

for changed_file in "${CHANGED_FILES[@]}"; do
  printf 'Arquivo avaliado: %s\n' "$changed_file"

  case "$changed_file" in
    scripts/validate-documentation.sh)
      ;;
    .env.example|\
    .github/workflows/pr-cache-cleanup.yml|\
    .github/workflows/portable.yml|\
    app/*|\
    contract-tests/*|\
    migration/baselines/*|\
    runtime/*|\
    scripts/*)
      runtime_changed=true
      selection_reason="runtime-impacting-path"
      ;;
  esac
done

printf 'Decisão portable-ci: runtime_changed=%s (%s)\n' \
  "$runtime_changed" "$selection_reason"
record_output "runtime_changed" "$runtime_changed"
record_output "selection_reason" "$selection_reason"
