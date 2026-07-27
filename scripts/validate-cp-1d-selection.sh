#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
DECISION="$REPOSITORY_ROOT/docs/cp-1d-runtime-selection.md"

if [[ $# -ne 0 ]]; then
  printf 'Uso: ./scripts/validate-cp-1d-selection.sh\n' >&2
  exit 2
fi

for path in "$MANIFEST" "$DECISION"; do
  if [[ ! -f "$path" ]]; then
    printf 'FALHA: arquivo obrigatório ausente: %s\n' \
      "${path#"$REPOSITORY_ROOT"/}" >&2
    exit 1
  fi
done

awk -F '\t' '
  NR == 1 {
    expected = "component\tversion\tartifact\torigin\tlicense\tsha256\tlifecycle\tscope"
    if ($0 != expected) {
      print "FALHA: cabeçalho inválido no manifesto portátil" > "/dev/stderr"
      exit 1
    }
    next
  }
  NF != 8 {
    print "FALHA: registro inválido no manifesto portátil: linha " NR > "/dev/stderr"
    exit 1
  }
  $6 !~ /^[0-9a-f]{64}$/ {
    print "FALHA: SHA-256 inválido no manifesto portátil: linha " NR > "/dev/stderr"
    exit 1
  }
  $7 != "EOL" || $8 != "portable-ci" {
    print "FALHA: lifecycle ou escopo inválido no manifesto portátil: linha " NR > "/dev/stderr"
    exit 1
  }
  {
    count[$1]++
    version[$1] = $2
    artifact[$1] = $3
    origin[$1] = $4
  }
  END {
    if (count["zulu-openjdk"] != 1 || count["h2"] != 1 || NR != 3) {
      print "FALHA: manifesto deve fixar somente Zulu OpenJDK e H2" > "/dev/stderr"
      exit 1
    }
    if (version["zulu-openjdk"] != "7.56.0.11-ca / OpenJDK 1.7.0_352-b01" ||
        artifact["zulu-openjdk"] != "zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz") {
      print "FALHA: build Zulu Java 7 aprovada foi alterada" > "/dev/stderr"
      exit 1
    }
    if (version["h2"] != "1.4.200" ||
        artifact["h2"] != "h2-1.4.200.jar") {
      print "FALHA: versão H2 aprovada foi alterada" > "/dev/stderr"
      exit 1
    }
    if (origin["zulu-openjdk"] ~ /latest/ || origin["h2"] ~ /latest/) {
      print "FALHA: origem flutuante não é permitida" > "/dev/stderr"
      exit 1
    }
  }
' "$MANIFEST"

while IFS=$'\t' read -r component version artifact origin license sha256 lifecycle scope; do
  [[ "$component" == "component" ]] && continue
  for required_text in "$version" "$artifact" "$sha256" "$lifecycle" "$scope"; do
    if ! grep -Fq "$required_text" "$DECISION"; then
      printf 'FALHA: decisão não registra valor do manifesto para %s\n' \
        "$component" >&2
      exit 1
    fi
  done
done < "$MANIFEST"

if git -C "$REPOSITORY_ROOT" ls-files '*.jar' | grep -q .; then
  printf 'FALHA: há JAR versionado no repositório\n' >&2
  exit 1
fi

printf 'OK: seleção portátil Java 7/H2 do CP-1D validada\n'
