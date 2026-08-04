#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPOSITORY_ROOT"

run_step() {
  local label="$1"
  shift
  printf '\n==> %s\n' "$label"
  "$@"
}

shell_files=(
  scripts/doctor.sh
  scripts/prepare-portable-runtime-cache.sh
  scripts/validate-repository-baseline.sh
  scripts/validate-cp-1b.sh
  scripts/audit-legacy-war.sh
  scripts/build-cp-1c.sh
  scripts/validate-cp-1c.sh
  scripts/validate-cp-1d-selection.sh
  scripts/validate-cp-1d-profiles.sh
  scripts/validate-cp-1d-h2.sh
  scripts/validate-cp-1d-datasources.sh
  scripts/build-cp-1d.sh
  scripts/smoke-wildfly9-datasource.sh
  scripts/follow-wildfly9-log.sh
  scripts/oracle-lab-schema.sh
  scripts/qualify-cp-2c-oracle.sh
  scripts/validate-documentation.sh
  scripts/validate-cp-1e-persistence.sh
  scripts/validate-cp-1e-web.sh
  scripts/validate-cp-1f-upload.sh
  scripts/validate-cp-1f-xml.sh
  scripts/validate-cp-1f-discovery-logging.sh
  scripts/validate-cp-1f-contracts.sh
  scripts/validate-cp-1g-baseline.sh
  scripts/build-cp-2a.sh
  scripts/validate-cp-2a.sh
  scripts/smoke-wildfly26-datasource.sh
  scripts/validate-cp-2b.sh
  scripts/validate-cp-2c-oracle-persistence.sh
  scripts/validate-cp-2c.sh
  scripts/qualify-cp-2d-h2.sh
  scripts/qualify-cp-2d-oracle.sh
  scripts/validate-cp-2d-oracle-state.sh
  scripts/validate-cp-2d-phase-comparison.sh
  scripts/validate-cp-2d-manifest.sh
  scripts/validate-cp-2d-real-runbook.sh
  scripts/validate-cp-2d-reproduction.sh
  scripts/validate-cp-2d-closure.sh
  scripts/reproduce-cp-2d.sh
  scripts/build-cp-3a.sh
  scripts/qualify-cp-3a-h2.sh
  scripts/qualify-cp-3a-oracle.sh
  scripts/smoke-cp-3a-datasource.sh
  scripts/validate-cp-3a.sh
  scripts/build-cp-3b.sh
  scripts/qualify-cp-3b-h2.sh
  scripts/qualify-cp-3b-oracle.sh
  scripts/smoke-cp-3b-datasource.sh
  scripts/validate-cp-3b.sh
  scripts/qualify-cp-3d-h2.sh
  scripts/qualify-cp-3d-oracle.sh
  scripts/validate-cp-3d.sh
  scripts/validate-cp-3d-tiles-tld.sh
  scripts/diagnose-cp-3e-unchanged.sh
  scripts/build-cp-3e-jakarta.sh
  scripts/validate-cp-3e-entry.sh
  scripts/build-cp-3f-jakarta.sh
  scripts/rebuild-cp-3f-ide.sh
  scripts/validate-cp-3f-namespace.sh
  scripts/validate-cp-3f-closure.sh
  scripts/validate-cp-3g-tiles.sh
  scripts/validate-cp-3g-upload.sh
  scripts/validate-cp-3g-discovery.sh
  scripts/smoke-wildfly41-datasource.sh
  contract-tests/run.sh
)

run_step "Validar sintaxe dos scripts shell" bash -n "${shell_files[@]}"
run_step "Validar baseline do repositório" ./scripts/doctor.sh CP-1A --ci
run_step "Validar identidade e origens do cache portátil" \
  ./scripts/prepare-portable-runtime-cache.sh --validate-only
run_step "Validar recursos estáticos do CP-1B" \
  ./scripts/validate-cp-1b.sh --release
run_step "Validar recursos estáticos do CP-1C" ./scripts/validate-cp-1c.sh
run_step "Validar seleção de runtime do CP-1D" \
  ./scripts/validate-cp-1d-selection.sh
run_step "Validar perfis e proteções do CP-1D" \
  ./scripts/validate-cp-1d-profiles.sh
run_step "Validar scripts H2 do CP-1D" ./scripts/validate-cp-1d-h2.sh
run_step "Validar perfis de datasource do CP-1D" \
  ./scripts/validate-cp-1d-datasources.sh
run_step "Validar persistência do CP-1E" \
  ./scripts/validate-cp-1e-persistence.sh
run_step "Validar camada web do CP-1E" ./scripts/validate-cp-1e-web.sh
run_step "Validar documentação consolidada" \
  ./scripts/validate-documentation.sh
run_step "Validar upload legado do CP-1F" \
  ./scripts/validate-cp-1f-upload.sh
run_step "Validar importação XML legada do CP-1F" \
  ./scripts/validate-cp-1f-xml.sh
run_step "Validar Reflections e Log4j do CP-1F" \
  ./scripts/validate-cp-1f-discovery-logging.sh
run_step "Validar contratos externos do CP-1F" \
  ./scripts/validate-cp-1f-contracts.sh
run_step "Validar baseline congelado do CP-1G" \
  ./scripts/validate-cp-1g-baseline.sh
run_step "Validar transição Java 8 do CP-2A" ./scripts/validate-cp-2a.sh
run_step "Validar transição WildFly 26 do CP-2B" ./scripts/validate-cp-2b.sh
run_step "Validar alinhamento Jakarta EE 8 do CP-2C" \
  ./scripts/validate-cp-2c.sh
run_step "Validar comparação integral da fase 2" \
  ./scripts/validate-cp-2d-phase-comparison.sh
run_step "Validar manifesto da fase 2" \
  ./scripts/validate-cp-2d-manifest.sh
run_step "Validar roteiro da fase 2 para aplicação real" \
  ./scripts/validate-cp-2d-real-runbook.sh
run_step "Validar reprodução limpa da fase 2" \
  ./scripts/validate-cp-2d-reproduction.sh
run_step "Validar candidato de encerramento da fase 2" \
  ./scripts/validate-cp-2d-closure.sh
run_step "Validar tentativa inicial do CP-3A no Java 17" \
  ./scripts/validate-cp-3a.sh
run_step "Validar atualização do MyBatis no CP-3B" \
  ./scripts/validate-cp-3b.sh
run_step "Validar exceção Tiles/TLD do CP-3D" \
  ./scripts/validate-cp-3d-tiles-tld.sh
run_step "Validar gate Java 17 do CP-3D" \
  ./scripts/validate-cp-3d.sh
run_step "Validar entrada do CP-3E no WildFly 41" \
  ./scripts/validate-cp-3e-entry.sh
run_step "Validar namespaces e descritores Jakarta do CP-3F" \
  ./scripts/validate-cp-3f-namespace.sh
run_step "Validar multipart nativo do CP-3G" \
  ./scripts/validate-cp-3g-upload.sh
run_step "Validar descoberta SCI do CP-3G" \
  ./scripts/validate-cp-3g-discovery.sh

printf '\nOK: repository-baseline local e remoto concluído\n'
