#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_HOME_ARGUMENT=""
H2_JAR_ARGUMENT=""
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-cp1e.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-1e-persistence.sh
  ./scripts/validate-cp-1e-persistence.sh \
    --java-home DIRETORIO --h2-jar ARQUIVO [--war ARQUIVO]

Sem argumentos, valida estaticamente a configuração. Com Java, H2 e um WAR já
construído, executa também os mappers e os limites transacionais em memória.
USAGE
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    "${TMPDIR:-/tmp}"/wildfly-migration-cp1e.*)
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
    --war)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --war exige um arquivo\n' >&2
        exit 2
      }
      WAR_FILE="$2"
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

required_paths=(
  "app/src/main/java/br/com/asillos/migration/domain/StatusPedido.java"
  "app/src/main/java/br/com/asillos/migration/domain/Pedido.java"
  "app/src/main/java/br/com/asillos/migration/domain/Anexo.java"
  "app/src/main/java/br/com/asillos/migration/persistence/PedidoMapper.java"
  "app/src/main/java/br/com/asillos/migration/persistence/AnexoMapper.java"
  "app/src/main/java/br/com/asillos/migration/persistence/StatusPedidoTypeHandler.java"
  "app/src/main/java/br/com/asillos/migration/persistence/Sha256TypeHandler.java"
  "app/src/main/java/br/com/asillos/migration/persistence/MyBatisBootstrap.java"
  "app/src/main/java/br/com/asillos/migration/persistence/MyBatisTransactionTemplate.java"
  "app/src/main/java/br/com/asillos/migration/persistence/AnexoRepository.java"
  "app/src/main/java/br/com/asillos/migration/persistence/PedidoRepository.java"
  "app/src/main/resources/mybatis-config.xml"
  "app/src/main/resources/mybatis/PedidoMapper.xml"
  "app/src/main/resources/mybatis/AnexoMapper.xml"
  "docs/mybatis-persistence.md"
  "scripts/ValidateLegacyPersistence.java"
  "scripts/ValidateLegacyMyBatis.java"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: recurso de persistência ausente: %s\n' "$path" >&2
    exit 1
  fi
done

install -d -m 0755 "$TEMP_DIRECTORY/static"
javac -Xlint:-options -source 1.7 -target 1.7 \
  -d "$TEMP_DIRECTORY/static" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyPersistence.java"
java -cp "$TEMP_DIRECTORY/static" \
  ValidateLegacyPersistence "$REPOSITORY_ROOT"

if grep -REiq \
    'jdbc:(oracle|h2):|ORACLE_DB_(URL|USER|PASSWORD)|password[[:space:]]*=' \
    "$REPOSITORY_ROOT/app/src/main/java" \
    "$REPOSITORY_ROOT/app/src/main/resources/mybatis-config.xml" \
    "$REPOSITORY_ROOT/app/src/main/resources/mybatis"; then
  printf 'FALHA: endpoint ou credencial foi incluído na persistência\n' >&2
  exit 1
fi

if [[ -z "$JAVA_HOME_ARGUMENT" ]]; then
  exit 0
fi

if [[ ! -x "$JAVA_HOME_ARGUMENT/bin/java" ||
      ! -x "$JAVA_HOME_ARGUMENT/bin/javac" ||
      ! -x "$JAVA_HOME_ARGUMENT/bin/jar" ]]; then
  printf 'FALHA: Java informado não é um JDK completo\n' >&2
  exit 1
fi
if [[ ! -f "$H2_JAR_ARGUMENT" || ! -f "$WAR_FILE" ]]; then
  printf 'FALHA: H2 e WAR construído são obrigatórios na validação dinâmica\n' >&2
  exit 1
fi
WAR_FILE="$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")"

expected_h2_checksum="$(
  awk -F '\t' '$1 == "h2" { print $6 }' \
    "$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
)"
actual_h2_checksum="$(sha256sum "$H2_JAR_ARGUMENT" | awk '{print $1}')"
if [[ "$actual_h2_checksum" != "$expected_h2_checksum" ]]; then
  printf 'FALHA: checksum do H2 diverge do manifesto portátil\n' >&2
  exit 1
fi

(
  cd "$TEMP_DIRECTORY"
  "$JAVA_HOME_ARGUMENT/bin/jar" xf "$WAR_FILE"
)

MYBATIS_JAR="$TEMP_DIRECTORY/WEB-INF/lib/mybatis-3.4.5.jar"
if [[ ! -f "$MYBATIS_JAR" ]]; then
  printf 'FALHA: MyBatis 3.4.5 não está presente no WAR auditado\n' >&2
  exit 1
fi

classpath="$TEMP_DIRECTORY/WEB-INF/classes:$MYBATIS_JAR:$H2_JAR_ARGUMENT"
install -d -m 0755 "$TEMP_DIRECTORY/probe"
"$JAVA_HOME_ARGUMENT/bin/javac" \
  -Xlint:-options -source 1.7 -target 1.7 \
  -cp "$classpath" \
  -d "$TEMP_DIRECTORY/probe" \
  "$REPOSITORY_ROOT/scripts/ValidateLegacyMyBatis.java"

"$JAVA_HOME_ARGUMENT/bin/java" \
  -cp "$TEMP_DIRECTORY/probe:$classpath" \
  ValidateLegacyMyBatis "$REPOSITORY_ROOT"
