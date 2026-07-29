#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POM="$REPOSITORY_ROOT/app/pom.xml"
EXPECTED_LIBRARIES="$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/war-libraries.txt"
RUNTIME_CACHE_LOCK="$REPOSITORY_ROOT/runtime/portable-runtime-cache.sha256"
WORKFLOW="$REPOSITORY_ROOT/.github/workflows/portable.yml"
WAR_FILE=""
TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp2c.XXXXXXXX"
)"

usage() {
  cat <<'USAGE'
Uso: ./scripts/validate-cp-2c.sh [--war ARQUIVO]

Sem argumentos, valida estaticamente o alinhamento ao Jakarta EE 8.
Com --war, comprova também a ausência de APIs do contêiner em WEB-INF/lib.
USAGE
}

fail() {
  printf 'FALHA CP-2C: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp2c.*)
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "argumento desconhecido: $1"
      ;;
  esac
done

for path in \
  "$POM" \
  "$EXPECTED_LIBRARIES" \
  "$RUNTIME_CACHE_LOCK" \
  "$WORKFLOW" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv" \
  "$REPOSITORY_ROOT/docs/cp-2c-ee8-maven-datasource.md" \
  "$REPOSITORY_ROOT/scripts/build-cp-2c.sh" \
  "$REPOSITORY_ROOT/scripts/ValidateApplicationPom.java" \
  "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh"; do
  [[ -f "$path" ]] ||
    fail "arquivo obrigatório ausente: ${path#"$REPOSITORY_ROOT/"}"
done

for cache_marker in \
  'uses: actions/cache/restore@v5' \
  'uses: actions/cache/save@v5' \
  'path: ${{ runner.temp }}/wildfly-migration-cache/runtime-archives' \
  "key: runtime-archives-v4-\${{ runner.os }}-\${{ runner.arch }}-\${{ hashFiles('runtime/portable-runtime-cache.sha256') }}" \
  'runtime-archives-v4-${{ runner.os }}-${{ runner.arch }}-' \
  'path: ~/.m2/repository' \
  'key: maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.8.9-${{ hashFiles(' \
  'maven-repository-v3-${{ runner.os }}-${{ runner.arch }}-maven-3.8.9-' \
  'key: ${{ steps.runtime-archive-cache.outputs.cache-primary-key }}' \
  'key: ${{ steps.maven-dependency-cache.outputs.cache-primary-key }}'; do
  grep -Fq "$cache_marker" "$WORKFLOW" ||
    fail "workflow não contém o cache reutilizável: $cache_marker"
done

if [[ "$(grep -Fc 'uses: actions/cache/restore@v5' "$WORKFLOW")" -ne 2 ]] ||
   [[ "$(grep -Fc 'uses: actions/cache/save@v5' "$WORKFLOW")" -ne 2 ]]; then
  fail "workflow deve restaurar e salvar exatamente os caches de runtime e Maven"
fi

if [[ "$(grep -Fc \
    "github.event_name == 'push' && github.ref == 'refs/heads/main'" \
    "$WORKFLOW")" -ne 2 ]]; then
  fail "caches novos devem ser gravados somente por push bem-sucedido na main"
fi

if grep -Fq 'uses: actions/cache@v5' "$WORKFLOW"; then
  fail "action combinada não deve gravar cache durante pull requests"
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

for token_workflow in \
  "$REPOSITORY_ROOT/.github/workflows/validate.yml" \
  "$WORKFLOW"; do
  grep -Fq 'persist-credentials: false' "$token_workflow" ||
    fail "checkout deve tratar o token como credencial efêmera"
done

for marker in \
  '<modelVersion>4.0.0</modelVersion>' \
  '<id>enforce-phase2-toolchain</id>' \
  '<version>[3.9.16]</version>'; do
  grep -Fq "$marker" "$POM" ||
    fail "POM não contém o contrato Maven do CP-2C: $marker"
done

grep -Fq -- '--java 8 --maven 3.9.16' \
  "$REPOSITORY_ROOT/scripts/build-cp-2c.sh" ||
  fail "wrapper CP-2C não fixa Java 8 e Maven 3.9.16"

expected_maven_row=$'apache-maven\t3.9.16\tapache-maven-3.9.16-bin.tar.gz\thttps://downloads.apache.org/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz\tApache-2.0\t80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb\tsha512:831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6\tmaintained-current-stable\tCP-2C-and-later'
grep -Fxq "$expected_maven_row" \
  "$REPOSITORY_ROOT/runtime/phase2/java8-wildfly26/runtime-manifest.tsv" ||
  fail "manifesto da fase 2 não fixa a distribuição Maven 3.9.16 aprovada"

for marker in \
  '<jakarta.ee.web.api.version>8.0.0</jakarta.ee.web.api.version>' \
  '<groupId>jakarta.platform</groupId>' \
  '<artifactId>jakarta.jakartaee-web-api</artifactId>' \
  '<version>${jakarta.ee.web.api.version}</version>' \
  '<scope>provided</scope>'; do
  grep -Fq "$marker" "$POM" ||
    fail "POM não contém o contrato EE 8: $marker"
done

for forbidden_coordinate in \
  '<artifactId>servlet-api</artifactId>' \
  '<artifactId>jsp-api</artifactId>' \
  '<artifactId>jstl-api</artifactId>' \
  '<artifactId>javaee-web-api</artifactId>'; do
  if grep -Fq "$forbidden_coordinate" "$POM"; then
    fail "POM ainda contém API histórica separada: $forbidden_coordinate"
  fi
done

if grep -R -E \
    '^[[:space:]]*import[[:space:]]+jakarta\.(servlet|el)\.' \
    "$REPOSITORY_ROOT/app/src/main/java"; then
  fail "CP-2C não deve antecipar a migração de namespace do gate Jakarta"
fi

grep -Fq -- \
  '- [x] 2.11 Alinhar as APIs do build a Jakarta EE 8' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.11 não está concluída no OpenSpec"

grep -Fq -- \
  '- [x] 2.12 Atualizar a ferramenta de build de Maven 3.8.9 para Maven 3.9.16' \
  "$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md" ||
  fail "tarefa 2.12 não está concluída no OpenSpec"

if [[ -n "$WAR_FILE" ]]; then
  [[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
  unzip -Z1 "$WAR_FILE" >"$TEMP_DIRECTORY/war-entries.txt"

  awk '
    /^WEB-INF\/lib\/[^/]+\.jar$/ {
      sub(/^WEB-INF\/lib\//, "")
      print
    }
  ' "$TEMP_DIRECTORY/war-entries.txt" |
    LC_ALL=C sort >"$TEMP_DIRECTORY/actual-libraries.txt"

  if grep -Eq \
      '^WEB-INF/lib/(servlet-api|javax\.servlet-api|jakarta\.servlet-api|jsp-api|javax\.servlet\.jsp-api|jakarta\.servlet\.jsp-api|jstl-api|javax\.servlet\.jsp\.jstl-api|jakarta\.servlet\.jsp\.jstl-api|javax\.el-api|jakarta\.el-api|javaee-api|javaee-web-api|jakarta\.jakartaee-api|jakarta\.jakartaee-web-api)-[^/]+\.jar$' \
      "$TEMP_DIRECTORY/war-entries.txt"; then
    fail "WAR contém uma API fornecida pelo WildFly"
  fi

  LC_ALL=C sort "$EXPECTED_LIBRARIES" \
    >"$TEMP_DIRECTORY/expected-libraries.txt"
  diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
    "$TEMP_DIRECTORY/actual-libraries.txt" ||
    fail "WEB-INF/lib diverge da allowlist da fase 2"
fi

printf 'OK: build alinhado ao Jakarta EE Web Profile 8 e Maven 3.9.16'
if [[ -n "$WAR_FILE" ]]; then
  printf ', sem APIs do contêiner em WEB-INF/lib'
fi
printf '\n'
