#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVES_DIRECTORY=""
CACHE_LOCK="$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
SOURCE_INDEX="$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv"
VALIDATE_ONLY=false

usage() {
  cat <<'USAGE'
Uso: ./scripts/prepare-portable-runtime-cache.sh \
  [--archives-dir DIRETORIO] [--lock ARQUIVO] [--sources ARQUIVO] \
  [--validate-only]

Valida a identidade e as origens do cache portátil. Sem --validate-only,
também reaproveita arquivos válidos, remove arquivos obsoletos e baixa apenas
os arquivos ausentes ou com SHA-256 incorreto.
USAGE
}

fail() {
  printf 'FALHA cache portátil: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --archives-dir)
      [[ $# -ge 2 ]] || fail "--archives-dir exige um diretório"
      ARCHIVES_DIRECTORY="$2"
      shift 2
      ;;
    --lock)
      [[ $# -ge 2 ]] || fail "--lock exige um arquivo"
      CACHE_LOCK="$2"
      shift 2
      ;;
    --sources)
      [[ $# -ge 2 ]] || fail "--sources exige um arquivo"
      SOURCE_INDEX="$2"
      shift 2
      ;;
    --validate-only)
      VALIDATE_ONLY=true
      shift
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

[[ -f "$CACHE_LOCK" ]] || fail "lock ausente: $CACHE_LOCK"
[[ -f "$SOURCE_INDEX" ]] || fail "índice de origens ausente: $SOURCE_INDEX"
if [[ "$VALIDATE_ONLY" != true && -z "$ARCHIVES_DIRECTORY" ]]; then
  fail "--archives-dir é obrigatório sem --validate-only"
fi

declare -A approved_sha256=()
declare -A source_count=()
lock_entries=0
line_number=0

while IFS= read -r lock_line || [[ -n "$lock_line" ]]; do
  line_number=$((line_number + 1))
  [[ -z "$lock_line" || "$lock_line" == \#* ]] && continue

  read -r expected_sha256 archive_name trailing <<< "$lock_line"
  [[ -n "${expected_sha256:-}" &&
     -n "${archive_name:-}" &&
     -z "${trailing:-}" ]] ||
    fail "linha inválida no lock: $line_number"
  [[ "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] ||
    fail "SHA-256 inválido no lock para $archive_name"
  [[ "$archive_name" != */* &&
     "$archive_name" != "." &&
     "$archive_name" != ".." ]] ||
    fail "nome de arquivo inseguro no lock: $archive_name"
  [[ -z "${approved_sha256[$archive_name]+present}" ]] ||
    fail "arquivo duplicado no lock: $archive_name"

  approved_sha256["$archive_name"]="$expected_sha256"
  lock_entries=$((lock_entries + 1))
done < "$CACHE_LOCK"

[[ "$lock_entries" -gt 0 ]] || fail "lock não contém arquivos"

line_number=0
while IFS=$'\t' read -r archive_name origin trailing ||
      [[ -n "${archive_name:-}${origin:-}${trailing:-}" ]]; do
  line_number=$((line_number + 1))
  [[ -z "${archive_name:-}" || "$archive_name" == \#* ]] && continue
  [[ -n "${origin:-}" && -z "${trailing:-}" ]] ||
    fail "linha inválida no índice de origens: $line_number"
  [[ -n "${approved_sha256[$archive_name]+present}" ]] ||
    fail "origem sem arquivo correspondente no lock: $archive_name"
  [[ "$origin" == https://* ]] ||
    fail "origem deve usar HTTPS para $archive_name"
  source_count["$archive_name"]=$((
    ${source_count[$archive_name]:-0} + 1
  ))
done < "$SOURCE_INDEX"

for archive_name in "${!approved_sha256[@]}"; do
  [[ "${source_count[$archive_name]:-0}" -gt 0 ]] ||
    fail "arquivo sem origem registrada: $archive_name"
done

printf 'OK: %d arquivos do cache portátil possuem SHA-256 e origem HTTPS\n' \
  "$lock_entries"

if [[ "$VALIDATE_ONLY" == true ]]; then
  exit 0
fi

install -d -m 0755 "$ARCHIVES_DIRECTORY"

while IFS= read -r -d '' cached_path; do
  cached_name="${cached_path##*/}"
  if [[ -z "${approved_sha256[$cached_name]+present}" ]]; then
    printf 'Removendo arquivo obsoleto do cache restaurado: %s\n' \
      "$cached_name"
    rm -f -- "$cached_path"
  fi
done < <(
  find "$ARCHIVES_DIRECTORY" -mindepth 1 -maxdepth 1 -type f -print0
)

ensure_archive() {
  local expected_sha256="$1"
  local archive_name="$2"
  local archive_path="$ARCHIVES_DIRECTORY/$archive_name"
  local partial_path="${archive_path}.part"
  local candidate_name
  local origin
  local trailing

  if [[ -f "$archive_path" ]] &&
     printf '%s  %s\n' "$expected_sha256" "$archive_path" |
       sha256sum --check --status; then
    printf 'Cache validado por SHA-256: %s\n' "$archive_name"
    return
  fi

  rm -f -- "$archive_path" "$partial_path"
  while IFS=$'\t' read -r candidate_name origin trailing ||
        [[ -n "${candidate_name:-}${origin:-}${trailing:-}" ]]; do
    [[ "$candidate_name" == "$archive_name" ]] || continue

    printf 'Baixando da origem registrada: %s\n' "$archive_name"
    printf 'Origem: %s\n' "$origin"
    if curl --retry 3 --retry-all-errors \
        -fsSLo "$partial_path" "$origin" &&
       printf '%s  %s\n' "$expected_sha256" "$partial_path" |
         sha256sum --check --status; then
      mv -f -- "$partial_path" "$archive_path"
      printf 'Download validado por SHA-256: %s\n' "$archive_name"
      return
    fi
    printf 'Origem indisponível ou conteúdo inválido: %s\n' \
      "$origin" >&2
    rm -f -- "$partial_path"
  done < "$SOURCE_INDEX"

  fail "nenhuma origem produziu o arquivo aprovado: $archive_name"
}

while IFS= read -r lock_line || [[ -n "$lock_line" ]]; do
  [[ -z "$lock_line" || "$lock_line" == \#* ]] && continue
  read -r expected_sha256 archive_name <<< "$lock_line"
  ensure_archive "$expected_sha256" "$archive_name"
done < "$CACHE_LOCK"

(
  cd "$ARCHIVES_DIRECTORY"
  sha256sum --check "$CACHE_LOCK"
)
