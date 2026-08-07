#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR="$ROOT/app/target/cp3j-java25/wildfly-migration.war"
REPORT="$ROOT/migration/evidence/CP-3K/reproduction-oracle.json"
OUTPUT="$ROOT/migration/evidence/CP-3K/audit.properties"

fail() {
  printf 'FALHA auditoria CP-3K/3.54: %s\n' "$1" >&2
  exit 1
}

[[ -d "$ROOT/.git" ]] || fail 'checkout Git ausente'
[[ -f "$WAR" ]] || fail 'WAR Java 25 ausente; execute a reprodução antes da auditoria'
[[ -f "$REPORT" ]] || fail 'evidência Oracle da reprodução ausente'

required_subjects=(
  'checkpoint(CP-1G): complete legacy baseline'
  'checkpoint(CP-2D): complete low-impact modernization'
  'checkpoint(CP-3A): establish Java 17 runtime'
  'checkpoint(CP-3B): modernize core dependencies'
  'checkpoint(CP-3C): modernize XML and JDBC'
  'checkpoint(CP-3D): approve Java 17 gate'
  'checkpoint(CP-3E): enter WildFly 41 and Jakarta EE 11'
  'checkpoint(CP-3F): migrate Jakarta namespaces'
  'checkpoint(CP-3G): replace legacy web libraries'
  'checkpoint(CP-3H): finalize Oracle and packaging'
  'checkpoint(CP-3I): approve Java 21 Jakarta gate'
  'checkpoint(CP-3J): qualify OpenJDK 25'
)
for subject in "${required_subjects[@]}"; do
  history_subjects="$(git -C "$ROOT" log --all --tags --format='%s')"
  [[ $'\n'"$history_subjects"$'\n' == *$'\n'"$subject"$'\n'* ]] ||
    fail "commit de checkpoint ausente: $subject"
done

for tag in migration/01-legacy-baseline migration/02-java8-wildfly26; do
  git -C "$ROOT" rev-parse --verify "refs/tags/$tag^{commit}" >/dev/null 2>&1 ||
    fail "tag pública ausente: $tag"
done
if git -C "$ROOT" rev-parse --verify refs/tags/migration/03-final >/dev/null 2>&1; then
  fail 'tag final foi criada antes do fechamento CP-3K'
fi

for closure in \
  migration/evidence/CP-2D/closure.properties \
  migration/evidence/CP-3I/closure.properties \
  migration/evidence/CP-3J/closure.properties; do
  [[ -f "$ROOT/$closure" ]] || fail "fechamento ausente: $closure"
done
for pr in 18 20 21 23 24 25 28 29 30; do
  grep -RqsE "(#$pr|pull-request=$pr)" "$ROOT/docs" "$ROOT/migration/evidence" ||
    fail "PR sem rastreabilidade documental: #$pr"
done

if git -C "$ROOT" grep -nE \
    'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]+PRIVATE KEY-----|jdbc:oracle:[^[:space:]<]+' \
    -- ':!*.jar' ':!*.war' ':!scripts/**' ':!docs/**' ':!.env.example' ':!openspec/**' >/dev/null; then
  fail 'padrão de segredo ou URL Oracle encontrado no conteúdo versionado'
fi
if git -C "$ROOT" ls-files | grep -E '(^|/)\.env$|(^|/).*\.pem$|(^|/).*\.key$|(^|/)oracle-wallet/' >/dev/null; then
  fail 'arquivo sensível está versionado'
fi

manifests=(
  runtime/legacy/runtime-manifest.tsv
  runtime/legacy/portable-runtime-manifest.tsv
  runtime/phase2/java8-wildfly26/runtime-manifest.tsv
  runtime/phase3/java17-wildfly26/runtime-manifest.tsv
  runtime/phase3/java21-wildfly41/runtime-manifest.tsv
  runtime/phase3/java25-wildfly41/runtime-manifest.tsv
)
for manifest in "${manifests[@]}"; do
  [[ -f "$ROOT/$manifest" ]] || fail "manifesto ausente: $manifest"
  if ! awk -F '\t' 'NR > 1 && ($1 == "" || $2 == "" || $4 !~ /^https:\/\// ||
      $5 == "" || $6 !~ /^[0-9a-f]{64}$/) { bad=1 } END { exit bad }' "$ROOT/$manifest"; then
    fail "origem, licença ou SHA-256 inválido: $manifest"
  fi
done
if ! awk -F '\t' 'NR > 1 && ($1 == "" || $2 !~ /^https:\/\//) { bad=1 } END { exit bad }' \
    "$ROOT/runtime/portable-runtime-sources.tsv"; then
  fail 'origem do cache portátil inválida'
fi

"$ROOT/scripts/audit-cp-3h-final-packaging.sh" --war "$WAR"
war_sha256="$(sha256sum "$WAR" | awk '{print $1}')"
report_sha256="$(sed -n 's/.*"warSha256": "\([0-9a-f]\{64\}\)".*/\1/p' "$REPORT" | head -n 1)"
[[ "$war_sha256" == "$report_sha256" ]] || fail 'checksum do WAR diverge da reprodução Oracle'
for rollback in \
  migration/evidence/CP-3I/rollback.properties \
  migration/evidence/CP-3J/rollback.properties; do
  grep -Fxq 'rollback.result=verified-by-documentation' "$ROOT/$rollback" ||
    fail "rollback não verificado: $rollback"
done
grep -Fqs 'Reprodução e rollback' "$ROOT/docs/evidence/CP-3K.md" &&
  grep -Fqs 'Falhas e rollback' "$ROOT/docs/cp-3k-reproduction.md" ||
  fail 'rollback do CP-3K não está documentado'

mkdir -p "$(dirname "$OUTPUT")"
cat >"$OUTPUT" <<EOF
schema=wildfly-migration-cp3k-audit/v1
checkpoint=CP-3K
activity=3.54
source.commit=$(git -C "$ROOT" rev-parse HEAD)
checkpoint.commits=${#required_subjects[@]}
public.tags=2
final.tag=absent-before-3.55
pull.requests=9
secret.scan=passed
license.scan=passed
checksum.scan=passed
dependency.audit=passed
war.sha256=$war_sha256
war.audit=passed
rollback.audit=passed
result=passed
EOF

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=|senha=' "$OUTPUT"; then
  fail 'evidência de auditoria contém configuração sensível'
fi
printf 'OK: auditoria CP-3K/3.54 passou; evidência em %s\n' "$OUTPUT"
