#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$REPOSITORY_ROOT/docs/phase2-real-application-migration-runbook.md"
DOCUMENTATION_INDEX="$REPOSITORY_ROOT/docs/README.md"
EVIDENCE_DOCUMENT="$REPOSITORY_ROOT/docs/evidence/CP-2D.md"
MANIFEST_LIMITATIONS="$REPOSITORY_ROOT/migration/baselines/02-java8-wildfly26/known-limitations.tsv"

fail() {
  printf 'FALHA CP-2D roteiro real: %s\n' "$1" >&2
  exit 1
}

for path in \
  "$RUNBOOK" \
  "$DOCUMENTATION_INDEX" \
  "$EVIDENCE_DOCUMENT" \
  "$MANIFEST_LIMITATIONS"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for section in \
  '# Roteiro da fase 2 para uma aplicação real' \
  '## Objetivo e limites' \
  '## Princípios de segurança da mudança' \
  '## Papéis e autorizações' \
  '## Pré-condições obrigatórias' \
  '## Topologia blue/green' \
  '## Preparação do Green' \
  '## Verificações antes da janela' \
  '## Janela de transição' \
  '## Decisão go/no-go' \
  '## Execução do corte' \
  '## Critérios de rollback' \
  '## Procedimento de rollback' \
  '## Evidências da execução real' \
  '## Correspondência com o laboratório' \
  '## Conclusão da estabilização'; do
  grep -Fq "$section" "$RUNBOOK" ||
    fail "seção obrigatória ausente: $section"
done

for marker in \
  'Não atualize uma instalação existente do WildFly in-place.' \
  'java:/jdbc/MigrationDS' \
  'quiescência de escrita' \
  'T-30 dias' \
  'T-7 dias' \
  'T-24 horas' \
  'T-60 minutos' \
  'T0' \
  'T+30 minutos' \
  'T+120 minutos' \
  'portable-ci' \
  'nunca qualifica Oracle' \
  'decisão é `no-go`' \
  'rollback de tráfego e runtime' \
  'Nunca faça restauração cega do banco' \
  'dois grupos de nós escrevendo simultaneamente' \
  'sessões HTTP, uploads, arquivos temporários, caches, jobs e' \
  'Preserve o Green isolado para investigação' \
  'WildFly 26, Java 8 e as bibliotecas legadas continuam sendo uma ponte'; do
  grep -Fq "$marker" "$RUNBOOK" ||
    fail "controle operacional ausente: $marker"
done

for role in \
  'responsável pela mudança' \
  'equipe da aplicação' \
  'equipe de plataforma' \
  'DBA Oracle' \
  'segurança' \
  'representante de negócio'; do
  grep -Fq "| $role |" "$RUNBOOK" ||
    fail "papel obrigatório ausente: $role"
done

for gate in \
  'artefato' \
  'runtime' \
  'empacotamento' \
  'datasource' \
  'contrato' \
  'Oracle' \
  'integrações' \
  'segurança' \
  'operação' \
  'rollback'; do
  grep -Fq "| $gate |" "$RUNBOOK" ||
    fail "gate obrigatório ausente: $gate"
done

for laboratory_mapping in \
  'doctor.sh CP-2D' \
  'build-cp-2c.sh' \
  'validate-cp-2d-manifest.sh' \
  'qualify-cp-2d-h2.sh' \
  'qualify-cp-2d-oracle.sh' \
  'phase2-comparison.json'; do
  grep -Fq "$laboratory_mapping" "$RUNBOOK" ||
    fail "correspondência com o laboratório ausente: $laboratory_mapping"
done

limitation_count="$(
  awk -F '\t' 'NR > 1 { count++ } END { print count + 0 }' \
    "$MANIFEST_LIMITATIONS"
)"
[[ "$limitation_count" == "12" ]] ||
  fail "roteiro depende das 12 limitações congeladas da fase 2"
grep -Fq 'known-limitations.tsv' "$RUNBOOK" ||
  fail "roteiro não referencia as limitações congeladas"
grep -Fq '../migration/baselines/02-java8-wildfly26/' "$RUNBOOK" ||
  fail "roteiro não referencia o manifesto da fase 2"

grep -Fq \
  '[Roteiro da fase 2 para uma aplicação real](phase2-real-application-migration-runbook.md)' \
  "$DOCUMENTATION_INDEX" ||
  fail "índice não aponta para o roteiro real"
grep -Fq '## Roteiro para aplicação real — atividade 2.18' \
  "$EVIDENCE_DOCUMENT" ||
  fail "evidência CP-2D não registra a atividade 2.18"

if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password=|user-name=|connection-url=' \
    "$RUNBOOK"; then
  fail "roteiro contém configuração sensível"
fi
if grep -Eiq \
    'DROP USER|DROP SCHEMA|git reset --hard|rm -rf' \
    "$RUNBOOK"; then
  fail "roteiro contém operação destrutiva inadequada"
fi

printf 'OK: roteiro blue/green da fase 2 contém janela, gates, go/no-go e rollback seguro\n'
