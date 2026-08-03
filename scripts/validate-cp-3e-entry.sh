#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESULT="$ROOT/migration/evidence/CP-3E/unchanged-war.json"
LOG="$ROOT/migration/evidence/CP-3E/unchanged-war-server.txt"
BUILD_RESULT="$ROOT/migration/evidence/CP-3E/jakarta-build.json"
BUILD_OUTPUT="$ROOT/migration/evidence/CP-3E/jakarta-build.txt"
OBSERVATIONS="$ROOT/migration/evidence/CP-3E/compatibility-observations.tsv"
MANIFEST="$ROOT/runtime/phase3/java21-wildfly41/runtime-manifest.tsv"

for file in "$RESULT" "$LOG" "$BUILD_RESULT" "$BUILD_OUTPUT" "$OBSERVATIONS" "$MANIFEST"; do
  [[ -f "$file" ]] || { printf 'FALHA: evidência CP-3E ausente: %s\n' "$file" >&2; exit 1; }
done

grep -Fq '"checkpoint": "CP-3E"' "$RESULT"
grep -Fq '"sourceCheckpoint": "CP-3D"' "$RESULT"
grep -Fq '"deploymentCommandStatus": "rejected"' "$RESULT"
grep -Fq '"unchangedWarAttempted": "passed"' "$RESULT"
grep -Fq '"compatibilityOutcomeCaptured": "passed"' "$RESULT"
grep -Fq 'WFLYCTL0021' "$LOG" || grep -Fq 'WFLYCTL0013' "$LOG"
grep -Fq 'javax.servlet.http.HttpServlet' "$LOG"
grep -Fq 'javax.servlet.jsp.tagext.TryCatchFinally' "$LOG"
grep -Fq '"profile": "cp-3e-jakarta11"' "$BUILD_RESULT"
grep -Fq '"api": "jakarta.platform:jakarta.jakartaee-web-api:11.0.0"' "$BUILD_RESULT"
grep -Fq '"expectedBeforeCp3f": true' "$BUILD_RESULT"
grep -Fq 'javax.servlet' "$BUILD_OUTPUT"
grep -Fq $'area\tobserved-on-entry\tseverity\tstatus\tdecision\trecord' "$OBSERVATIONS"
grep -Fq $'namespace\tjavax.servlet.http.HttpServlet' "$OBSERVATIONS"
grep -Fq $'datasource\tA tentativa de entrada' "$OBSERVATIONS"
grep -Fq $'temurin-openjdk\t21.0.12+8' "$MANIFEST"
grep -Fq $'wildfly-community-41\t41.0.0.Final' "$MANIFEST"
grep -Fq $'h2\t2.4.240' "$MANIFEST"

printf 'OK: entrada CP-3E e incompatibilidade javax/Jakarta validadas\n'
