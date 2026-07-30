#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv"
RUNTIME_CACHE_LOCK="$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
RUNTIME_CACHE_SOURCES="$REPOSITORY_ROOT/runtime/portable-runtime-sources.tsv"
EVIDENCE="$REPOSITORY_ROOT/migration/evidence/CP-2B/before-deployment.properties"
WAR_FILE=""
CONTRACT_RESULT_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2b.XXXXXXXX"
)"

fail() {
  printf 'FALHA CP-2B: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2b.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --contract-result)
      [[ $# -ge 2 ]] || fail "--contract-result exige um arquivo"
      CONTRACT_RESULT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      printf 'Uso: ./scripts/validate-cp-2b.sh [--war ARQUIVO] [--contract-result ARQUIVO]\n'
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

for path in \
  "$MANIFEST" \
  "$RUNTIME_CACHE_LOCK" \
  "$RUNTIME_CACHE_SOURCES" \
  "$EVIDENCE" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/compatibility-observations.tsv" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/after.properties" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/contract-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/contract-oracle.json" \
  "$REPOSITORY_ROOT/docs/cp-2b-wildfly26.md" \
  "$REPOSITORY_ROOT/docs/evidence/CP-2B.md" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/README.md" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/README.md" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/ci-h2.cli" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/oracle.cli" \
  "$REPOSITORY_ROOT/migration/steps/CP-2B-wildfly26-missing-datasource.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-2B-wildfly26-log4j-deprecation.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-2B-wildfly26-default-https.md" \
  "$REPOSITORY_ROOT/migration/steps/CP-2B-wildfly26-pool-name.md" \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

AFTER="$REPOSITORY_ROOT/migration/evidence/CP-2B/after.properties"
for marker in \
  'implementation.commit=5d1f6be20168909e8777a5f8a479e7d6b6d4a81a' \
  'app.changed=false' \
  'pom.changed=false' \
  'war.changed=false' \
  'datasource.jndi=java:/jdbc/MigrationDS' \
  'datasource.pool.test=passed' \
  'runtime.https.enabled=false' \
  'classloader.linkage-errors=0' \
  'portable-ci.result=passed' \
  'oracle-qualified.result=passed' \
  'logging.log4j1.active=true' \
  'logging.externalization=not-yet-qualified'; do
  grep -Fxq "$marker" "$AFTER" ||
    fail "evidência depois da correção não contém: $marker"
done

for evidence_contract in contract-ci-h2.json contract-oracle.json; do
  evidence_path="$REPOSITORY_ROOT/migration/evidence/CP-2B/$evidence_contract"
  grep -Fq '"commit": "5d1f6be20168909e8777a5f8a479e7d6b6d4a81a"' \
    "$evidence_path" ||
    fail "contrato CP-2B não aponta para o commit de implementação"
  grep -Fq '"warSha256": "bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4"' \
    "$evidence_path" ||
    fail "contrato CP-2B não aponta para o WAR aprovado"
  grep -Fq '"runtime": "java8-wildfly26.1.3"' "$evidence_path" ||
    fail "contrato CP-2B não identifica o runtime corrigido"
  [[ "$(grep -Ec '^[[:space:]]+\"[A-Za-z][A-Za-z0-9]*\": \"passed\",?$' "$evidence_path")" == "14" ]] ||
    fail "contrato CP-2B não contém os 14 cenários"
  if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$evidence_path"; then
    fail "contrato CP-2B contém configuração sensível"
  fi
done
grep -Fq '"qualification": "portable-ci"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/contract-ci-h2.json" ||
  fail "contrato H2 CP-2B perdeu a classificação portable-ci"
grep -Fq '"qualification": "oracle-qualified"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-2B/contract-oracle.json" ||
  fail "contrato Oracle CP-2B perdeu a qualificação"

for conclusion_marker in \
  'Conclusão comprovada' \
  'Configuração não acompanha o binário do servidor' \
  'Migração mínima do runtime' \
  'Equivalência funcional e persistência' \
  'Namespace, empacotamento e classloader preservados' \
  'Logging permanece uma limitação conhecida' \
  'Limites da conclusão'; do
  grep -Fq "$conclusion_marker" \
    "$REPOSITORY_ROOT/docs/evidence/CP-2B.md" ||
    fail "conclusão CP-2B não contém: $conclusion_marker"
done

for marker in \
  'source.commit=bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0' \
  'source.war.sha256=bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4' \
  'source.bytecode.major=52' \
  'code.changed=false' \
  'war.changed=false' \
  'deployment.status=FAILED' \
  'health.http-status=404' \
  'migration.datasource.present=false' \
  'result=expected-failure' \
  'failure.signature=javax.naming.NameNotFoundException-jdbc/MigrationDS'; do
  grep -Fxq "$marker" "$EVIDENCE" ||
    fail "evidência anterior à correção não contém: $marker"
done

grep -Fq $'INC-007\tCP-2B\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-007 não foi catalogada"
grep -Fq $'INC-008\tCP-2B\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-008 não foi catalogada"
grep -Fq $'INC-009\tCP-2B\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-009 não foi catalogada"
grep -Fq $'INC-010\tCP-2B\t' \
  "$REPOSITORY_ROOT/migration/incompatibilities.tsv" ||
  fail "INC-010 não foi catalogada"
grep -Fq -- '- [x] 2.6 Tentar implantar no WildFly 26.1.3' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.6 não está concluída"
grep -Fq -- '- [x] 2.7 Capturar incompatibilidades de configuração' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.7 não está concluída"
grep -Fq -- '- [x] 2.8 Provisionar WildFly 26.1.3/Java 8' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.8 não está concluída"
grep -Fq -- '- [x] 2.9 Configurar no WildFly 26 os perfis H2 e Oracle' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.9 não está concluída"
grep -Fq -- '- [x] 2.10 Encerrar `CP-2B`' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.10 não está concluída"

OBSERVATIONS="$REPOSITORY_ROOT/migration/evidence/CP-2B/compatibility-observations.tsv"
[[ "$(head -n 1 "$OBSERVATIONS")" == \
  $'area\tbaseline-wildfly9\ttarget-wildfly26\tseverity\tdecision\trecord' ]] ||
  fail "cabeçalho da matriz de compatibilidade divergente"
for area in configuration datasource security logging classloader; do
  [[ "$(awk -F '\t' -v wanted="$area" '$1 == wanted { count++ } END { print count + 0 }' "$OBSERVATIONS")" == "1" ]] ||
    fail "matriz deve conter exatamente uma observação para $area"
done

for profile_file in \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/ci-h2.cli" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/profiles/oracle.cli"; do
  grep -Fq 'jndi-name=java:/jdbc/MigrationDS' "$profile_file" ||
    fail "perfil WildFly 26 não publica o JNDI aprovado"
  if grep -Fq 'pool-name=' "$profile_file"; then
    fail "perfil WildFly 26 reintroduziu o atributo pool-name incompatível"
  fi
done

grep -Fq -- '--server 26' \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh" ||
  fail "wrapper do CP-2B não fixa WildFly 26"
grep -Fq -- '--java 8' \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly26-datasource.sh" ||
  fail "wrapper do CP-2B não fixa Java 8"
grep -Fq 'https-listener name="https"' \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
  fail "runtime compartilhado não contém a regressão do HTTPS padrão"
grep -Fq 'ClassNotFoundException|NoClassDefFoundError' \
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
  fail "runtime compartilhado não verifica quebras de classloader"

expected_wildfly_row=$'wildfly-community\t26.1.3.Final\twildfly-26.1.3.Final.tar.gz\thttps://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.tar.gz\tLGPL-2.1-or-later\taadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59\tsha1:b9f52ba41df890e09bb141d72947d2510caf758c\tEOL-bridge-runtime\tCP-2B-and-CP-3A-to-CP-3D'
[[ "$(sed -n '3p' "$MANIFEST")" == "$expected_wildfly_row" ]] ||
  fail "registro WildFly 26 não corresponde à distribuição fixada"

grep -Fxq \
  'WILDFLY26_ARCHIVE_SHA256=aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59' \
  "$REPOSITORY_ROOT/.env.example" ||
  fail ".env.example não contém o SHA-256 fixado do WildFly 26"

for cache_lock_row in \
  'da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e  OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz' \
  '80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb  apache-maven-3.9.16-bin.tar.gz' \
  'aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59  wildfly-26.1.3.Final.tar.gz' \
  '3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6  h2-1.4.200.jar'; do
  grep -Fxq "$cache_lock_row" "$RUNTIME_CACHE_LOCK" ||
    fail "identidade do cache de runtime não contém: $cache_lock_row"
done

STATIC_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/validate.yml"
WORKFLOW="$REPOSITORY_ROOT/.github/workflows/portable.yml"
for action_marker in \
  'uses: actions/checkout@v6' \
  'uses: actions/upload-artifact@v6'; do
  grep -Fq "$action_marker" "$WORKFLOW" ||
    fail "workflow do CP-2B não usa a action Node 24: $action_marker"
done
if grep -Eq 'uses: actions/(checkout|upload-artifact)@v4' \
    "$STATIC_WORKFLOW" "$WORKFLOW"; then
  fail "workflow do CP-2B não deve usar actions baseadas em Node 20"
fi
for concurrent_workflow in "$STATIC_WORKFLOW" "$WORKFLOW"; do
  grep -Fq 'group: ${{ github.workflow }}-${{ github.ref }}' \
    "$concurrent_workflow" ||
    fail "workflow não isola concorrência por workflow e referência"
  grep -Fq 'cancel-in-progress: true' "$concurrent_workflow" ||
    fail "workflow não cancela execução obsoleta da mesma referência"
  grep -Fq 'persist-credentials: false' "$concurrent_workflow" ||
    fail "checkout não deve persistir o token no runner"
done
for path_marker in \
  '".env.example"' \
  '".github/workflows/pr-cache-cleanup.yml"' \
  '".github/workflows/portable.yml"' \
  '"app/**"' \
  '"contract-tests/**"' \
  '"migration/baselines/**"' \
  '"runtime/**"' \
  '"scripts/**"'; do
  grep -Fq "$path_marker" "$WORKFLOW" ||
    fail "portable-ci não declara caminho aplicável: $path_marker"
done
if grep -Fq '"docs/**"' "$WORKFLOW"; then
  fail "portable-ci não deve executar por alteração exclusivamente documental"
fi
for cache_marker in \
  'uses: actions/cache/restore@v5' \
  'uses: actions/cache/save@v5' \
  'path: ${{ runner.temp }}/wildfly-migration-cache/runtime-archives' \
  "key: runtime-archives-v4-\${{ runner.os }}-\${{ runner.arch }}-\${{ hashFiles('runtime/portable-runtime-cache.sha256') }}" \
  'runtime-archives-v4-${{ runner.os }}-${{ runner.arch }}-' \
  'path: ~/.m2/repository' \
  'key: maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.9.16-${{ hashFiles(' \
  'maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.9.16-' \
  "hashFiles('app/pom.xml')" \
  'archives="$RUNNER_TEMP/wildfly-migration-cache/runtime-archives"' \
  'cache_lock="$GITHUB_WORKSPACE/runtime/portable-runtime-cache.sha256"' \
  'runtime_sources="$GITHUB_WORKSPACE/runtime/portable-runtime-sources.tsv"' \
  './scripts/prepare-portable-runtime-cache.sh \' \
  '--archives-dir "$archives" \' \
  '--lock "$cache_lock" \' \
  '--sources "$runtime_sources"' \
  'key: ${{ steps.runtime-archive-cache.outputs.cache-primary-key }}' \
  'key: ${{ steps.maven-dependency-cache.outputs.cache-primary-key }}'; do
  grep -Fq -- "$cache_marker" "$WORKFLOW" ||
    fail "cache portátil do CP-2B não contém: $cache_marker"
done
for source_marker in \
  'apache-maven-3.9.16-bin.tar.gz	https://downloads.apache.org/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz' \
  'apache-maven-3.9.16-bin.tar.gz	https://archive.apache.org/dist/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz'; do
  grep -Fq -- "$source_marker" "$RUNTIME_CACHE_SOURCES" ||
    fail "índice de origens do cache não contém: $source_marker"
done
if [[ "$(grep -Fc 'uses: actions/cache/restore@v5' "$WORKFLOW")" -ne 2 ]] ||
   [[ "$(grep -Fc 'uses: actions/cache/save@v5' "$WORKFLOW")" -ne 2 ]]; then
  fail "portable-ci deve restaurar e salvar exatamente os caches de runtime e Maven"
fi
if [[ "$(grep -Fc 'restore-keys:' "$WORKFLOW")" -ne 2 ]]; then
  fail "os dois caches reutilizáveis devem declarar chave parcial"
fi
for save_guard in \
  "github.event_name == 'push'" \
  "github.ref == 'refs/heads/main'" \
  "github.event_name == 'pull_request'" \
  "github.event.pull_request.head.repo.full_name ==" \
  "github.repository"; do
  if [[ "$(grep -Fc "$save_guard" "$WORKFLOW")" -ne 2 ]]; then
    fail "os dois caches não compartilham a proteção de gravação: $save_guard"
  fi
done
if grep -Fq 'uses: actions/cache@v5' "$WORKFLOW"; then
  fail "política de gravação exige actions separadas de restore e save"
fi
if grep -Eq \
    'key: cp-[0-9]|wildfly-migration-cache/cp-[0-9]' \
    "$WORKFLOW"; then
  fail "chave ou caminho de cache não deve depender de checkpoint"
fi
if grep -Ei \
    '^[[:space:]]+(key|path):.*(github\.token|GITHUB_TOKEN|GH_TOKEN|secrets\.)' \
    "$WORKFLOW"; then
  fail "token ou secret não pode participar de chave ou caminho de cache"
fi
if awk '
  /^[[:space:]]+- name:/ {
    cache_action = 0
  }
  /uses: actions\/cache\/(restore|save)@v5/ {
    cache_action = 1
  }
  cache_action &&
      /path: .*settings\.xml|path: .*app\/target|path: .*contract-results/ {
    unsafe_path = 1
  }
  END {
    exit unsafe_path ? 0 : 1
  }
' "$WORKFLOW"; then
  fail "cache do CP-2B inclui configuração ou resultado que deve ser recriado"
fi
if grep -Fq 'path: .cache/' "$WORKFLOW"; then
  fail "cache do CP-2B não deve ficar dentro do checkout"
fi

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  [[ "$(sha256sum "$WAR_FILE" | awk '{print $1}')" == \
    "bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4" ]] ||
    fail "WAR informado não é o artefato aprovado no CP-2A"
  unzip -p "$WAR_FILE" \
    WEB-INF/classes/br/com/asillos/migration/LegacyBuildMarker.class \
    >"$TEMP_DIRECTORY/LegacyBuildMarker.class"
  javap -verbose "$TEMP_DIRECTORY/LegacyBuildMarker.class" |
    grep -Fq 'major version: 52' ||
    fail "WAR informado não contém bytecode Java 8 major 52"
fi

if [[ -n "$CONTRACT_RESULT_FILE" ]]; then
  [[ -f "$CONTRACT_RESULT_FILE" ]] ||
    fail "resultado de contrato informado não existe"
  current_commit="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
  for marker in \
    '"schema": "wildfly-migration-contract-result/v1"' \
    '"qualification": "portable-ci"' \
    '"profile": "ci-h2"' \
    "\"commit\": \"$current_commit\"" \
    '"warSha256": "bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4"' \
    '"runtime": "java8-wildfly26.1.3"'; do
    grep -Fq "$marker" "$CONTRACT_RESULT_FILE" ||
      fail "resultado portátil atual não contém: $marker"
  done
  [[ "$(grep -Ec '^[[:space:]]+\"[A-Za-z][A-Za-z0-9]*\": \"passed\",?$' \
      "$CONTRACT_RESULT_FILE")" == "14" ]] ||
    fail "resultado portátil atual não contém os 14 cenários aprovados"
  if grep -Eiq \
    'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$CONTRACT_RESULT_FILE"; then
    fail "resultado portátil atual contém configuração sensível"
  fi
fi

printf 'OK: tentativa sem correção do WAR CP-2A no WildFly 26 está registrada'
if [[ -n "$WAR_FILE" ]]; then
  printf ', WAR aprovado preservado'
fi
if [[ -n "$CONTRACT_RESULT_FILE" ]]; then
  printf ', contratos portáteis atuais aprovados'
fi
printf '\n'
