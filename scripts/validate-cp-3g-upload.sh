#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAR="$ROOT/app/target/wildfly-migration.war"

fail() {
  printf 'FALHA CP-3G/3.32: %s\n' "$1" >&2
  exit 1
}

required=(
  "app/pom.xml"
  "app/src/main/java/br/com/asillos/migration/web/MultipartPartSupport.java"
  "app/src/main/java/br/com/asillos/migration/web/UploadServlet.java"
  "app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java"
  "migration/steps/CP-3G-servlet-multipart.md"
  "migration/evidence/CP-3G/upload-ci-h2.json"
  "migration/evidence/CP-3G/upload-oracle.json"
)
for path in "${required[@]}"; do
  [[ -f "$ROOT/$path" ]] || fail "arquivo obrigatório ausente: $path"
done

validate_evidence() {
  local file="$1"
  local qualification="$2"
  local profile="$3"
  for marker in \
    '"schema": "wildfly-migration-cp3g-upload/v1"' \
    '"checkpoint": "CP-3G"' \
    '"activity": "3.32"' \
    "\"qualification\": \"$qualification\"" \
    "\"profile\": \"$profile\"" \
    '"workingTree": true' \
    '"api": "jakarta.servlet.http.Part"' \
    '"fileUploadDependency": "absent"' \
    '"commonsIoDependency": "absent"' \
    '"scenarios": 15' \
    '"upload": "passed"' \
    '"uploadLimit": "passed"' \
    '"temporaryCleanup": "passed"' \
    '"result": "passed"'; do
    grep -Fq "$marker" "$file" || fail "evidência não contém: $marker"
  done
  if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha' "$file"; then
    fail "evidência contém configuração sensível"
  fi
}

validate_evidence "$ROOT/migration/evidence/CP-3G/upload-ci-h2.json" \
  portable-ci ci-h2
validate_evidence "$ROOT/migration/evidence/CP-3G/upload-oracle.json" \
  oracle-qualified oracle

h2_source="$(sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
  "$ROOT/migration/evidence/CP-3G/upload-ci-h2.json")"
oracle_source="$(sed -n 's/.*"sourceCommit": "\([^"]*\)".*/\1/p' \
  "$ROOT/migration/evidence/CP-3G/upload-oracle.json")"
h2_war="$(sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
  "$ROOT/migration/evidence/CP-3G/upload-ci-h2.json")"
oracle_war="$(sed -n 's/.*"warSha256": "\([^"]*\)".*/\1/p' \
  "$ROOT/migration/evidence/CP-3G/upload-oracle.json")"
[[ "$h2_source" =~ ^[0-9a-f]{40}$ && "$h2_source" == "$oracle_source" ]] ||
  fail 'evidências H2 e Oracle não usam o mesmo commit-fonte'
[[ "$h2_war" =~ ^[0-9a-f]{64}$ && "$h2_war" == "$oracle_war" ]] ||
  fail 'evidências H2 e Oracle não usam o mesmo WAR'

if grep -Eq 'commons\.fileupload|commons\.io' "$ROOT/app/pom.xml"; then
  fail 'POM ainda declara Commons FileUpload ou Commons IO'
fi
if rg -n 'org\.apache\.commons\.fileupload|ServletFileUpload|FileItem|DiskFileItemFactory|JakartaFileUploadRequestContext' \
    "$ROOT/app/src/main/java"; then
  fail 'código ativo ainda referencia Commons FileUpload'
fi

for source in \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/UploadServlet.java" \
  "$ROOT/app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java"; do
  grep -Fq '@MultipartConfig' "$source" ||
    fail "@MultipartConfig ausente em ${source##*/}"
  grep -Fq 'MultipartPartSupport.parse(request)' "$source" ||
    fail "request.getParts() não está encapsulado em ${source##*/}"
  grep -Fq 'part.delete()' "$source" ||
    fail "limpeza de Part ausente em ${source##*/}"
done

for marker in \
  'maxFileSize = AnexoRepository.MAX_FILE_BYTES' \
  'maxRequestSize = UploadServlet.MAX_REQUEST_BYTES' \
  'maxFileSize = XmlImportServlet.MAX_XML_BYTES' \
  'maxRequestSize = XmlImportServlet.MAX_MULTIPART_REQUEST_BYTES' \
  'submittedFileName' \
  'getInputStream()'; do
  grep -Fq "$marker" \
    "$ROOT/app/src/main/java/br/com/asillos/migration/web/MultipartPartSupport.java" \
    "$ROOT/app/src/main/java/br/com/asillos/migration/web/UploadServlet.java" \
    "$ROOT/app/src/main/java/br/com/asillos/migration/web/XmlImportServlet.java" ||
    fail "contrato multipart não contém: $marker"
done

if [[ -f "$WAR" ]]; then
  entries="$(mktemp)"
  trap 'rm -f "$entries"' EXIT
  jar tf "$WAR" >"$entries"
  if grep -Eiq '^WEB-INF/lib/(commons-fileupload|commons-io)-' "$entries"; then
    fail 'WAR ainda contém Commons FileUpload ou Commons IO'
  fi
  grep -Fq 'WEB-INF/classes/br/com/asillos/migration/web/MultipartPartSupport.class' \
    "$entries" || fail 'WAR não contém MultipartPartSupport'
fi

printf 'OK: CP-3G/3.32 usa multipart Servlet nativo, limites e limpeza sem Commons FileUpload\n'
