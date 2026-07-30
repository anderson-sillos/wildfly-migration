#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENT_NAME="${PORTABLE_EVENT_NAME:-${GITHUB_EVENT_NAME:-}}"
EVENT_ACTION="${PORTABLE_EVENT_ACTION:-}"
BEFORE_SHA="${PORTABLE_BEFORE_SHA:-}"
AFTER_SHA="${PORTABLE_AFTER_SHA:-}"
PR_BASE_SHA="${PORTABLE_PR_BASE_SHA:-}"
PR_HEAD_SHA="${PORTABLE_PR_HEAD_SHA:-}"
REPOSITORY="${PORTABLE_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
CHANGED_FILE="${PORTABLE_CHANGED_FILE:-}"
PREVIOUS_SUCCESS_OVERRIDE="${PORTABLE_PREVIOUS_SUCCESS:-}"
OUTPUT_FILE="${GITHUB_OUTPUT:-}"

fail() {
  printf 'FALHA: %s\n' "$1" >&2
  exit 1
}

[[ -n "$EVENT_NAME" ]] || fail "evento GitHub ausente"
[[ -n "$OUTPUT_FILE" ]] || fail "GITHUB_OUTPUT ausente"
case "$PREVIOUS_SUCCESS_OVERRIDE" in
  ""|true|false)
    ;;
  *)
    fail "PORTABLE_PREVIOUS_SUCCESS aceita somente true ou false"
    ;;
esac

if [[ -n "$CHANGED_FILE" ]]; then
  changed_files=("$CHANGED_FILE")
else
  if [[ "$EVENT_NAME" == "pull_request" &&
        "$EVENT_ACTION" == "synchronize" ]]; then
    comparison_base="$BEFORE_SHA"
    comparison_head="$AFTER_SHA"
  elif [[ "$EVENT_NAME" == "pull_request" ]]; then
    comparison_base="$PR_BASE_SHA"
    comparison_head="$PR_HEAD_SHA"
  else
    comparison_base="$BEFORE_SHA"
    comparison_head="$AFTER_SHA"
  fi

  if ! git cat-file -e "${comparison_base}^{commit}" 2>/dev/null ||
     ! git cat-file -e "${comparison_head}^{commit}" 2>/dev/null; then
    changed_files=(".git-reference-unavailable")
  else
    mapfile -d '' -t changed_files < <(
      git diff --name-only -z --no-renames --diff-filter=ACMRTD \
        "$comparison_base" "$comparison_head" --
    )
  fi
fi

runtime_changed=false
reason="documentation-or-planning-only"
for changed_file in "${changed_files[@]}"; do
  printf 'Arquivo avaliado: %s\n' "$changed_file"
  case "$changed_file" in
    migration/baselines/*)
      runtime_changed=true
      reason="runtime-impacting-path"
      ;;
    *.md|\
    docs/*|\
    openspec/*|\
    migration/evidence/*|\
    migration/steps/*|\
    migration/incompatibilities.tsv|\
    scripts/validate-documentation.sh)
      ;;
    *)
      runtime_changed=true
      reason="runtime-impacting-path"
      ;;
  esac
done

if [[ "$runtime_changed" == "true" ]]; then
  printf 'Decisão por caminhos: CI completo (%s)\n' "$reason"
else
  printf 'Decisão por caminhos: modo leve (%s)\n' "$reason"
fi

previous_success=false
if [[ "$runtime_changed" != "true" &&
      "$EVENT_NAME" == "pull_request" &&
      "$EVENT_ACTION" == "synchronize" ]]; then
  if [[ -n "$PREVIOUS_SUCCESS_OVERRIDE" ]]; then
    previous_success="$PREVIOUS_SUCCESS_OVERRIDE"
  elif [[ -n "$REPOSITORY" && -n "$BEFORE_SHA" ]] &&
       result="$(
         gh api \
           "repos/$REPOSITORY/commits/$BEFORE_SHA/check-runs" \
           --jq 'any(.check_runs[]; .name == "portable-ci" and .conclusion == "success")'
       )" &&
       [[ "$result" == "true" ]]; then
    previous_success=true
  fi
fi

run_portable=true
if [[ "$runtime_changed" != "true" ]]; then
  if [[ "$EVENT_NAME" == "pull_request" &&
        "$EVENT_ACTION" == "synchronize" &&
        "$previous_success" != "true" ]]; then
    reason="previous-head-without-successful-portable-check"
  else
    run_portable=false
  fi
fi

{
  printf 'runtime_changed=%s\n' "$runtime_changed"
  printf 'previous_success=%s\n' "$previous_success"
  printf 'run=%s\n' "$run_portable"
  printf 'reason=%s\n' "$reason"
} >> "$OUTPUT_FILE"

printf 'portable-ci completo: %s (%s)\n' "$run_portable" "$reason"
