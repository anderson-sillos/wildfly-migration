#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H2_DIRECTORY="$REPOSITORY_ROOT/app/src/main/resources/db/h2"
ORACLE_DIRECTORY="$REPOSITORY_ROOT/app/src/main/resources/db/oracle"
JAVA_HOME_ARGUMENT=""
H2_JAR_ARGUMENT=""

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-1d-h2.sh
  ./scripts/validate-cp-1d-h2.sh --java-home DIRETORIO --h2-jar ARQUIVO

Sem argumentos, executa a validação estática. Com os dois argumentos, executa
também o schema, o seed e o rollback no H2 em memória.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --java-home)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --java-home exige um diretório\n' >&2
        exit 2
      }
      JAVA_HOME_ARGUMENT="$2"
      shift 2
      ;;
    --h2-jar)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --h2-jar exige um arquivo\n' >&2
        exit 2
      }
      H2_JAR_ARGUMENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'FALHA: argumento desconhecido: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -n "$JAVA_HOME_ARGUMENT" && -z "$H2_JAR_ARGUMENT" ||
      -z "$JAVA_HOME_ARGUMENT" && -n "$H2_JAR_ARGUMENT" ]]; then
  printf 'FALHA: --java-home e --h2-jar devem ser informados juntos\n' >&2
  exit 2
fi

required_files=(
  "app/src/main/resources/db/h2/001_schema.sql"
  "app/src/main/resources/db/h2/002_seed.sql"
  "app/src/main/resources/db/h2/rollback.sql"
  "app/src/main/resources/db/h2/README.md"
  "docs/h2-oracle-differences.md"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: arquivo H2 obrigatório ausente: %s\n' "$path" >&2
    exit 1
  fi
done

schema_objects=(
  LAB_PEDIDO_SEQ
  LAB_ANEXO_SEQ
  LAB_PEDIDO
  LAB_ANEXO
  IX_LAB_ANEXO_PEDIDO
)
constraints=(
  PK_LAB_PEDIDO
  UK_LAB_PEDIDO_NUMERO
  CK_LAB_PEDIDO_VALOR
  CK_LAB_PEDIDO_STATUS
  PK_LAB_ANEXO
  FK_LAB_ANEXO_PEDIDO
  CK_LAB_ANEXO_TAMANHO
  CK_LAB_ANEXO_SHA256
)

for name in "${schema_objects[@]}" "${constraints[@]}"; do
  if ! grep -Fq "$name" "$ORACLE_DIRECTORY/001_schema.sql" ||
     ! grep -Fq "$name" "$H2_DIRECTORY/001_schema.sql"; then
    printf 'FALHA: objeto ou constraint não está espelhado: %s\n' "$name" >&2
    exit 1
  fi
done

if grep -Eiq \
    '(^|[[:space:]])(DECLARE|BEGIN|EXECUTE[[:space:]]+IMMEDIATE|USER_(TABLES|SEQUENCES|INDEXES)|VARCHAR2|NUMBER[[:space:]]*\()' \
    "$H2_DIRECTORY"/*.sql; then
  printf 'FALHA: construção exclusiva do Oracle foi copiada para o H2\n' >&2
  exit 1
fi

for pattern in \
  'CREATE SEQUENCE IF NOT EXISTS LAB_PEDIDO_SEQ' \
  'CREATE SEQUENCE IF NOT EXISTS LAB_ANEXO_SEQ' \
  'CREATE TABLE IF NOT EXISTS LAB_PEDIDO' \
  'CREATE TABLE IF NOT EXISTS LAB_ANEXO' \
  'CREATE INDEX IF NOT EXISTS IX_LAB_ANEXO_PEDIDO' \
  'DECIMAL(19, 0)' \
  'DECIMAL(15, 2)' \
  'TIMESTAMP(6)' \
  'CONTEUDO       BLOB' \
  "REGEXP_LIKE(SHA256, '^[0-9a-f]{64}$')"; do
  if ! grep -Fq "$pattern" "$H2_DIRECTORY/001_schema.sql"; then
    printf 'FALHA: contrato H2 ausente no schema: %s\n' "$pattern" >&2
    exit 1
  fi
done

for pattern in \
  'NEXT VALUE FOR LAB_PEDIDO_SEQ' \
  "'LAB-0001'" \
  "'Cliente de referência'" \
  "'Pedido mínimo para validar o baseline'" \
  '125.50' \
  "'NOVO'" \
  'WHERE NOT EXISTS' \
  'COMMIT;'; do
  if ! grep -Fq "$pattern" "$H2_DIRECTORY/002_seed.sql"; then
    printf 'FALHA: contrato H2 ausente no seed: %s\n' "$pattern" >&2
    exit 1
  fi
done

for name in LAB_ANEXO LAB_PEDIDO LAB_ANEXO_SEQ LAB_PEDIDO_SEQ; do
  if ! grep -Eq "^DROP (TABLE|SEQUENCE) IF EXISTS ${name};$" \
      "$H2_DIRECTORY/rollback.sql"; then
    printf 'FALHA: limpeza H2 não remove idempotentemente %s\n' "$name" >&2
    exit 1
  fi
done

if grep -Eiq \
    'jdbc:h2:(tcp|ssl)|AUTO_SERVER|createTcpServer|createWebServer|webPort' \
    "$H2_DIRECTORY"/*; then
  printf 'FALHA: listener ou console H2 detectado\n' >&2
  exit 1
fi

for topic in tipos constraints sequences timestamps LOBs; do
  if ! grep -Fiq "$topic" "$REPOSITORY_ROOT/docs/h2-oracle-differences.md"; then
    printf 'FALHA: documentação não cobre diferenças de %s\n' "$topic" >&2
    exit 1
  fi
done

printf 'OK: scripts H2 têm equivalência estrutural estática com o Oracle\n'

if [[ -z "$JAVA_HOME_ARGUMENT" ]]; then
  exit 0
fi

if [[ ! -x "$JAVA_HOME_ARGUMENT/bin/java" ]]; then
  printf 'FALHA: Java informado não contém bin/java\n' >&2
  exit 1
fi
if [[ ! -f "$H2_JAR_ARGUMENT" ]]; then
  printf 'FALHA: JAR H2 informado não existe\n' >&2
  exit 1
fi

case "$(basename "$H2_JAR_ARGUMENT")" in
  h2-1.4.200.jar)
    h2_manifest="$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
    ;;
  h2-2.4.240.jar)
    h2_manifest="$REPOSITORY_ROOT/runtime/phase3/java17-wildfly26/runtime-manifest.tsv"
    ;;
  *)
    printf 'FALHA: versão H2 não pertence a um gate aprovado\n' >&2
    exit 1
    ;;
esac
expected_h2_checksum="$(
  awk -F '\t' '$1 == "h2" { print $6 }' "$h2_manifest"
)"
actual_h2_checksum="$(sha256sum "$H2_JAR_ARGUMENT" | awk '{print $1}')"
if [[ "$actual_h2_checksum" != "$expected_h2_checksum" ]]; then
  printf 'FALHA: checksum do H2 diverge do manifesto portátil\n' >&2
  exit 1
fi

case "$H2_DIRECTORY" in
  *"'"*)
    printf 'FALHA: checkout com apóstrofo no caminho não é suportado pelo RUNSCRIPT\n' >&2
    exit 1
    ;;
esac

sql="
RUNSCRIPT FROM '$H2_DIRECTORY/001_schema.sql';
RUNSCRIPT FROM '$H2_DIRECTORY/002_seed.sql';
RUNSCRIPT FROM '$H2_DIRECTORY/001_schema.sql';
RUNSCRIPT FROM '$H2_DIRECTORY/002_seed.sql';
SELECT 'PEDIDOS=' || COUNT(*) FROM LAB_PEDIDO WHERE NUMERO = 'LAB-0001';
SELECT 'CONSTRAINTS=' || COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
 WHERE CONSTRAINT_NAME IN (
  'PK_LAB_PEDIDO', 'UK_LAB_PEDIDO_NUMERO', 'CK_LAB_PEDIDO_VALOR',
  'CK_LAB_PEDIDO_STATUS', 'PK_LAB_ANEXO', 'FK_LAB_ANEXO_PEDIDO',
  'CK_LAB_ANEXO_TAMANHO', 'CK_LAB_ANEXO_SHA256'
 );
SELECT 'SEQUENCES=' || COUNT(*) FROM INFORMATION_SCHEMA.SEQUENCES
 WHERE SEQUENCE_NAME IN ('LAB_PEDIDO_SEQ', 'LAB_ANEXO_SEQ');
SELECT 'INDEXES=' || COUNT(*) FROM INFORMATION_SCHEMA.INDEXES
 WHERE INDEX_NAME = 'IX_LAB_ANEXO_PEDIDO';
RUNSCRIPT FROM '$H2_DIRECTORY/rollback.sql';
RUNSCRIPT FROM '$H2_DIRECTORY/rollback.sql';
SELECT 'REMAINING=' || COUNT(*) FROM INFORMATION_SCHEMA.TABLES
 WHERE TABLE_NAME IN ('LAB_PEDIDO', 'LAB_ANEXO');
"

output="$(
  "$JAVA_HOME_ARGUMENT/bin/java" -cp "$H2_JAR_ARGUMENT" org.h2.tools.Shell \
    -url 'jdbc:h2:mem:cp1d_validation;MODE=Oracle;DB_CLOSE_DELAY=-1' \
    -user sa -password '' -sql "$sql" 2>&1
)"

for expected in PEDIDOS=1 CONSTRAINTS=8 SEQUENCES=2 INDEXES=1 REMAINING=0; do
  if ! grep -Fq "$expected" <<< "$output"; then
    printf 'FALHA: execução H2 não comprovou %s\n' "$expected" >&2
    exit 1
  fi
done

printf 'OK: scripts H2 executados duas vezes e limpos duas vezes em memória\n'
