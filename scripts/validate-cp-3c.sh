#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
TREE_FILE="$REPOSITORY_ROOT/app/target/dependency-tree.txt"
TASKS_FILE="$REPOSITORY_ROOT/openspec/changes/create-java-web-migration-lab/tasks.md"
CLOSURE_FILE="$REPOSITORY_ROOT/migration/evidence/CP-3C/closure.properties"
ROLLBACK_FILE="$REPOSITORY_ROOT/migration/evidence/CP-3C/rollback.properties"
TEMP_DIRECTORY="$(mktemp -d /tmp/wildfly-migration-cp3c-closure.XXXXXXXX)"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3c.sh [--war ARQUIVO] [--tree ARQUIVO]

Audita o fechamento do CP-3C: dependências, allowlist do WAR, evidências H2
e Oracle, rollback e estado de integração do PR.
USAGE
}

fail() {
  printf 'FALHA CP-3C: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3c-closure.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --war)
      [[ "$#" -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --tree)
      [[ "$#" -ge 2 ]] || fail "--tree exige um arquivo"
      TREE_FILE="$2"
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
  "$REPOSITORY_ROOT/app/pom.xml" \
  "$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/xmlbeans-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/dom4j-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/java-xml-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-oracle.json" \
  "$CLOSURE_FILE" "$ROLLBACK_FILE"; do
  [[ -f "$path" ]] || fail "arquivo obrigatório ausente: $path"
done
[[ -f "$WAR_FILE" ]] || fail "WAR ausente: $WAR_FILE"
[[ -f "$TREE_FILE" ]] || fail "árvore Maven ausente: $TREE_FILE"

for marker in \
  '<mybatis.version>3.5.19</mybatis.version>' \
  '<commons.fileupload.version>1.6.0</commons.fileupload.version>' \
  '<commons.io.version>2.19.0</commons.io.version>' \
  '<reflections.version>0.10.2</reflections.version>' \
  '<xmlbeans.version>5.3.0</xmlbeans.version>' \
  '<dom4j.version>2.2.0</dom4j.version>'; do
  grep -Fq "$marker" "$REPOSITORY_ROOT/app/pom.xml" ||
    fail "POM não contém: $marker"
done
for forbidden in \
  '<artifactId>xml-apis</artifactId>' \
  '<artifactId>geronimo-stax-api_1.0_spec</artifactId>' \
  '<groupId>com.oracle</groupId>' \
  '<artifactId>ojdbc7</artifactId>'; do
  if grep -Fq "$forbidden" "$REPOSITORY_ROOT/app/pom.xml"; then
    fail "dependência proibida reapareceu no POM: $forbidden"
  fi
done

if grep -Eiq \
    'xml-apis|geronimo-stax-api_1\.0_spec|stax-api|log4j:log4j:.*1\.2\.14|reflections:.*0\.9\.10|commons-fileupload:.*1\.2\.2' \
    "$TREE_FILE"; then
  fail "árvore Maven contém dependência legada removida"
fi

WAR_ENTRIES="$TEMP_DIRECTORY/war-entries.txt"
unzip -Z1 "$WAR_FILE" >"$WAR_ENTRIES"
ALLOWLIST="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/war-libraries.txt"
sed -n 's#^WEB-INF/lib/##p' "$WAR_ENTRIES" |
  sed '/^$/d' | sort >"$TEMP_DIRECTORY/actual-libraries.txt"
sort "$ALLOWLIST" >"$TEMP_DIRECTORY/expected-libraries.txt"
diff -u "$TEMP_DIRECTORY/expected-libraries.txt" \
  "$TEMP_DIRECTORY/actual-libraries.txt" >/dev/null ||
  fail "bibliotecas do WAR divergem da allowlist Java 17"
if grep -Eiq \
    '(^|/)(ojdbc|xml-apis|geronimo-stax-api_1\.0_spec|stax-api)[^/]*\.jar$' \
    "$WAR_ENTRIES"; then
  fail "WAR contém driver Oracle ou API XML duplicada"
fi

for evidence in \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-ci-h2.json" \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-oracle.json"; do
  grep -Fq '"warSha256": "0e431a2ec85e0918cc89ed91dcec5715e7872e18b8d57441d7ae781b4a5a5d5b"' "$evidence" ||
    fail "evidência final não referencia o WAR qualificado"
  grep -Fq '"timestampRoundTrip": "passed"' "$evidence" ||
    fail "evidência não comprova timestamp"
  grep -Fq '"blobRoundTrip": "passed"' "$evidence" ||
    fail "evidência não comprova BLOB"
done
grep -Fq '"qualification": "portable-ci"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-ci-h2.json" ||
  fail "evidência H2 não é portable-ci"
grep -Fq '"qualification": "oracle-qualified"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-oracle.json" ||
  fail "evidência Oracle não é oracle-qualified"
grep -Fq '"databaseVersion": "19.3.0.0.0"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-oracle.json" ||
  fail "evidência Oracle não registra 19.3.0.0.0"
grep -Fq '"jdbcDriver": "ojdbc17-23.26.2.0.0"' \
  "$REPOSITORY_ROOT/migration/evidence/CP-3C/ojdbc17-oracle.json" ||
  fail "evidência Oracle não registra ojdbc17"

for marker in \
  'schema=wildfly-migration-cp3c-closure/v1' \
  'checkpoint=CP-3C' \
  'pull-request=21' \
  'tested.commit=39b156cc91627f54a1a7af17c7a0bb2e237c0710' \
  'dependency.audit=passed' \
  'driver.cache=excluded' \
  'rollback.commit=84fb02f37e4eaf522d98de66697807b03dfa574a' \
  'squash.subject=checkpoint(CP-3C): modernize XML and JDBC'; do
  grep -Fxq "$marker" "$CLOSURE_FILE" ||
    fail "fechamento não contém: $marker"
done
grep -Fxq 'schema=wildfly-migration-cp3c-rollback/v1' "$ROLLBACK_FILE" ||
  fail "rollback CP-3C não possui schema"
grep -Fxq 'database.schema.changed=false' "$ROLLBACK_FILE" ||
  fail "rollback não comprova preservação do schema"

tested_commit="$(sed -n 's/^tested.commit=//p' "$CLOSURE_FILE")"
rollback_commit="$(sed -n 's/^rollback.commit=//p' "$CLOSURE_FILE")"
git -C "$REPOSITORY_ROOT" cat-file -e "$tested_commit^{commit}" 2>/dev/null ||
  fail "commit testado não existe no repositório"
git -C "$REPOSITORY_ROOT" cat-file -e "$rollback_commit^{commit}" 2>/dev/null ||
  fail "commit de rollback não existe no repositório"

if grep -Fq -- '- [x] 3.15 Encerrar' "$TASKS_FILE"; then
  grep -Fxq 'result=passed' "$CLOSURE_FILE" ||
    fail "tarefa 3.15 marcada, mas fechamento ainda não está passed"
else
  grep -Fxq 'result=ready-for-integration' "$CLOSURE_FILE" ||
    fail "fechamento pendente deve estar ready-for-integration"
fi

if grep -Eiq 'jdbc:oracle:|ORACLE_DB_|password|user-name|connection-url' \
    "$CLOSURE_FILE" "$ROLLBACK_FILE"; then
  fail "evidência de fechamento contém configuração sensível"
fi

printf 'OK: CP-3C auditou WAR, dependências, H2/Oracle, rollback e evidências\n'
