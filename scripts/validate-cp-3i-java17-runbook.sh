#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$ROOT/docs/cp-3d-reproduction.md"
INDEX="$ROOT/docs/README.md"
CP3D_EVIDENCE="$ROOT/docs/evidence/CP-3D.md"
CP3I_EVIDENCE="$ROOT/docs/evidence/CP-3I.md"
ROLLBACK="$ROOT/migration/evidence/CP-3D/rollback.properties"

fail() {
  printf 'FALHA CP-3I/3.44: %s\n' "$1" >&2
  exit 1
}

for path in "$RUNBOOK" "$INDEX" "$CP3D_EVIDENCE" "$CP3I_EVIDENCE" "$ROLLBACK"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: ${path#"$ROOT/"}"
done

for section in \
  '# Reprodução e rollback do CP-3D' \
  '## Pré-requisitos' \
  '## Execução incremental' \
  '## Conferência do gate' \
  '## Rollback' \
  '## Implantação equivalente em produção' \
  '## Critérios e procedimento de rollback' \
  '## Correspondência com o laboratório'; do
  grep -Fq "$section" "$RUNBOOK" || fail "seção obrigatória ausente: $section"
done

for marker in \
  'migration/02-java8-wildfly26' \
  'Temurin OpenJDK 17.0.20+8' \
  'WildFly Community 26.1.3.Final' \
  'java:/jdbc/MigrationDS' \
  'blue/green' \
  'nós Green isolados' \
  'sem atualizar o WildFly existente *in-place' \
  'health checks' \
  'A decisão é `go`' \
  'troca gradual de tráfego' \
  'schema Oracle' \
  'reprovisionar o artefato' \
  'portable-ci' \
  'oracle-qualified' \
  'doctor.sh CP-3D' \
  'qualify-cp-3d-h2.sh' \
  'qualify-cp-3d-oracle.sh' \
  'validate-cp-3d.sh' \
  'migration/evidence/CP-3D/'; do
  grep -Fq -- "$marker" "$RUNBOOK" || fail "controle operacional ausente: $marker"
done

grep -Fq 'cp-3d-reproduction.md' "$INDEX" ||
  fail 'índice de documentação não aponta para o roteiro do CP-3D'
grep -Fq 'cp-3d-reproduction.md' "$CP3D_EVIDENCE" ||
  fail 'evidência CP-3D não referencia o roteiro'
grep -Fq 'Atividade 3.44' "$CP3I_EVIDENCE" ||
  fail 'evidência CP-3I não registra a atividade 3.44'

for marker in \
  'rollback.target=migration/02-java8-wildfly26' \
  'rollback.databaseMutation=none' \
  'rollback.result=verified-by-documented-checkout'; do
  grep -Fq "$marker" "$ROLLBACK" || fail "rollback versionado não contém: $marker"
done

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url|senha|wallet' \
    "$RUNBOOK" "$CP3D_EVIDENCE"; then
  fail 'runbook ou evidência contém configuração sensível'
fi
if grep -Eiq 'DROP USER|DROP SCHEMA|git reset --hard|rm -rf' "$RUNBOOK"; then
  fail 'runbook contém operação destrutiva inadequada'
fi

printf 'OK: CP-3I/3.44 reprodução, implantação equivalente e rollback do gate Java 17 documentados\n'
