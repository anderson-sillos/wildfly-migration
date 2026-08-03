#!/usr/bin/env bash

set -eo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
WAR_FILE="$REPOSITORY_ROOT/app/target/wildfly-migration.war"
RESULT_FILE="$REPOSITORY_ROOT/app/target/contract-results/cp-3c-java-xml-ci-h2.json"
CLASSES_DIRECTORY="$REPOSITORY_ROOT/app/target/classes"
JAVA_HOME_VALUE="$JAVA17_HOME"
SKIP_BUILD=false
TEMP_DIRECTORY="$(mktemp -d "/tmp/wildfly-migration-cp3c-java-xml.XXXXXXXX")"

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/validate-cp-3c-java-xml.sh [--env ARQUIVO]
    [--war ARQUIVO] [--result ARQUIVO] [--skip-build]
    [--classes-directory DIRETORIO]

Constrói o WAR do gate Java 17, rejeita APIs XML duplicadas e comprova que
DOM, SAX, JAXP e StAX são fornecidos pelo módulo java.xml do JDK.
USAGE
}

fail() {
  printf 'FALHA CP-3C java.xml: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  case "$TEMP_DIRECTORY" in
    /tmp/wildfly-migration-cp3c-java-xml.*)
      rm -rf -- "$TEMP_DIRECTORY"
      ;;
    *)
      printf 'FALHA: diretório temporário inesperado; limpeza recusada\n' >&2
      ;;
  esac
}
trap cleanup EXIT

read_env_value() {
  local wanted_key="$1"
  local file="$2"
  awk -F= -v wanted="$wanted_key" '
    $1 == wanted {
      value = substr($0, index($0, "=") + 1)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      sub(/^'\''/, "", value)
      sub(/'\''$/, "", value)
      print value
      exit
    }
  ' "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || fail "--env exige um arquivo"
      ENV_FILE="$2"
      shift 2
      ;;
    --war)
      [[ $# -ge 2 ]] || fail "--war exige um arquivo"
      WAR_FILE="$2"
      shift 2
      ;;
    --result)
      [[ $# -ge 2 ]] || fail "--result exige um arquivo"
      RESULT_FILE="$2"
      shift 2
      ;;
    --classes-directory)
      [[ $# -ge 2 ]] || fail "--classes-directory exige um diretório"
      CLASSES_DIRECTORY="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
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

if [[ -z "$JAVA_HOME_VALUE" && -f "$ENV_FILE" ]]; then
  JAVA_HOME_VALUE="$(read_env_value JAVA17_HOME "$ENV_FILE")"
fi
[[ -x "$JAVA_HOME_VALUE/bin/java" && -x "$JAVA_HOME_VALUE/bin/javac" &&
   -x "$JAVA_HOME_VALUE/bin/jar" && -x "$JAVA_HOME_VALUE/bin/jdeps" ]] ||
  fail "JAVA17_HOME não aponta para um JDK 17 completo"

if [[ "$SKIP_BUILD" != true ]]; then
  "$REPOSITORY_ROOT/scripts/build-cp-3b.sh" \
    --profile ci-h2 --env "$ENV_FILE"
fi

[[ -f "$WAR_FILE" ]] || fail "WAR não encontrado: $WAR_FILE"

POM_FILE="$REPOSITORY_ROOT/app/pom.xml"
for forbidden in \
  '<groupId>xml-apis</groupId>' \
  '<artifactId>xml-apis</artifactId>' \
  '<groupId>org.apache.geronimo.specs</groupId>' \
  '<artifactId>geronimo-stax-api_1.0_spec</artifactId>' \
  '<xml.apis.version>' \
  '<geronimo.stax.version>'; do
  if grep -Fq -- "$forbidden" "$POM_FILE"; then
    fail "dependência ou propriedade XML removida reapareceu no POM: $forbidden"
  fi
done

DEPENDENCY_TREE="$REPOSITORY_ROOT/app/target/dependency-tree.txt"
[[ -f "$DEPENDENCY_TREE" ]] || fail "árvore Maven ausente: $DEPENDENCY_TREE"
if grep -Eiq \
    '(^|[^[:alnum:]_.-])(xml-apis|geronimo-stax-api_1\.0_spec|stax-api)([^[:alnum:]_.-]|$)' \
    "$DEPENDENCY_TREE"; then
  fail "árvore Maven ainda contém API XML duplicada"
fi

mkdir -p "$TEMP_DIRECTORY/war" "$TEMP_DIRECTORY/classes" \
  "$(dirname "$RESULT_FILE")"
(cd "$TEMP_DIRECTORY/war" &&
  "$JAVA_HOME_VALUE/bin/jar" xf "$WAR_FILE" WEB-INF/lib)

if find "$TEMP_DIRECTORY/war/WEB-INF/lib" -maxdepth 1 -type f \
    \( -name 'xml-apis-*.jar' \
       -o -name 'geronimo-stax-api_1.0_spec-*.jar' \
       -o -name 'stax-api-*.jar' \) -print -quit | grep -q .; then
  fail "WAR ainda empacota API XML duplicada"
fi

"$JAVA_HOME_VALUE/bin/javac" -Xlint:-options -source 17 -target 17 \
  -d "$TEMP_DIRECTORY/classes" \
  "$REPOSITORY_ROOT/scripts/ValidateJavaXmlModule.java"

JAVA_XML_RESULT="$("$JAVA_HOME_VALUE/bin/java" \
  -cp "$TEMP_DIRECTORY/classes" ValidateJavaXmlModule)"
printf '%s\n' "$JAVA_XML_RESULT" | tee "$RESULT_FILE"
grep -Fq '"apiModule":"java.xml"' "$RESULT_FILE" ||
  fail "sonda não comprovou o módulo java.xml"

MODULES="$("$JAVA_HOME_VALUE/bin/jdeps" \
  --multi-release 17 --ignore-missing-deps --print-module-deps \
  "$CLASSES_DIRECTORY/br/com/asillos/migration/integration/xml/LegacyPedidoXmlParser.class" \
  2>/dev/null || true)"
printf '%s\n' "$MODULES" >"$TEMP_DIRECTORY/jdeps.txt"
grep -Eq '(^|,)java\.xml(,|$)' "$TEMP_DIRECTORY/jdeps.txt" ||
  fail "jdeps não identificou a dependência java.xml no bytecode da aplicação"

printf 'OK: CP-3C java.xml validado; APIs XML duplicadas removidas e resultado em %s\n' \
  "$RESULT_FILE"
