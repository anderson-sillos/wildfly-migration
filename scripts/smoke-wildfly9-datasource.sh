#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPOSITORY_ROOT/.env"
PROFILE=""
WAR_FILE=""
MANUAL_MODE=false
TEMP_DIRECTORY=""
RUNTIME_HOME=""
SERVER_PID=""
SERVER_STARTED=false
ORACLE_SMOKE_CREATED=false

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/smoke-wildfly9-datasource.sh --profile ci-h2|oracle \
    [--env ARQUIVO] [--war ARQUIVO] [--manual]

Valores já exportados no ambiente prevalecem sobre o arquivo informado.
Sem --war, valida somente o datasource. Com --war, valida também o fluxo web.
Com --manual, mantém a aplicação ativa em loopback até Ctrl+C; exige --war.
No modo manual, imprime o caminho do log bruto do WildFly.
USAGE
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

read_env_value() {
  local wanted_key="$1"
  local file="$2"
  local line key value result="" count=0

  [[ -f "$file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue

    key="${line%%=*}"
    [[ "$key" == "$wanted_key" ]] || continue
    value="$(trim "${line#*=}")"
    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi
    result="$value"
    count=$((count + 1))
  done < "$file"

  (( count == 1 )) || return 1
  printf '%s' "$result"
}

configuration_value() {
  local key="$1"
  local current="${!key:-}"

  if [[ -n "$current" ]]; then
    printf '%s' "$current"
  else
    read_env_value "$key" "$ENV_FILE" || true
  fi
}

sanitize_oracle_output() {
  local line sanitized

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -n "${ORACLE_DB_URL_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_URL_VALUE"* ]] ||
       [[ -n "${ORACLE_DB_USER_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_USER_VALUE"* ]] ||
       [[ -n "${ORACLE_DB_PASSWORD_VALUE:-}" &&
          "$line" == *"$ORACLE_DB_PASSWORD_VALUE"* ]]; then
      printf '[linha omitida por conter configuração Oracle]\n'
      continue
    fi

    case "$line" in
      *jdbc:oracle:*|*ORACLE_DB_*|*connection-url*|*user-name*|\
      *password*|*PASSWORD*)
        printf '[linha omitida por conter configuração Oracle]\n'
        ;;
      *)
        sanitized="${line//"$TEMP_DIRECTORY"/<runtime-temporario>}"
        printf '%s\n' "$sanitized"
        ;;
    esac
  done
}

cleanup() {
  if [[ "$ORACLE_SMOKE_CREATED" == true && "$PROFILE" == "oracle" ]]; then
    ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
    ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
    ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
      "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
        cleanup-smokes --env "$ENV_FILE" >/dev/null 2>&1 || true
    ORACLE_SMOKE_CREATED=false
  fi

  if [[ "$SERVER_STARTED" == true && -n "$RUNTIME_HOME" ]]; then
    JAVA_HOME="${SELECTED_JAVA_HOME:-}" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:${SELECTED_MANAGEMENT_PORT:-9990}" \
      --commands=':shutdown' >/dev/null 2>&1 || true
  fi

  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$SERVER_PID" ]]; then
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi

  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      "${TMPDIR:-/tmp}"/wildfly-migration-datasource.*)
        rm -rf -- "$TEMP_DIRECTORY"
        ;;
      *)
        printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2
        ;;
    esac
  fi
}
trap cleanup EXIT

handle_signal() {
  exit 130
}
trap handle_signal HUP INT TERM

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --profile exige ci-h2 ou oracle\n' >&2
        exit 2
      }
      PROFILE="$2"
      shift 2
      ;;
    --env)
      [[ $# -ge 2 ]] || {
        printf 'FALHA: --env exige um arquivo\n' >&2
        exit 2
      }
      ENV_FILE="$2"
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
    --manual)
      MANUAL_MODE=true
      shift
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

case "$PROFILE" in
  ci-h2|oracle)
    ;;
  *)
    printf 'FALHA: informe --profile ci-h2 ou --profile oracle\n' >&2
    exit 2
    ;;
esac

if [[ "$MANUAL_MODE" == true && -z "$WAR_FILE" ]]; then
  printf 'FALHA: --manual exige --war\n' >&2
  exit 2
fi

if [[ -n "$WAR_FILE" ]]; then
  if [[ ! -f "$WAR_FILE" ]]; then
    printf 'FALHA: WAR não encontrado: %s\n' "$WAR_FILE" >&2
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    printf 'FALHA: curl é obrigatório para o smoke web\n' >&2
    exit 1
  fi
  WAR_FILE="$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")"
fi

WILDFLY9_HOME_VALUE="$(configuration_value WILDFLY9_HOME)"
WILDFLY9_ARCHIVE_VALUE="$(configuration_value WILDFLY9_ARCHIVE)"
HTTP_PORT_VALUE="$(configuration_value WILDFLY_HTTP_PORT)"
MANAGEMENT_PORT_VALUE="$(configuration_value WILDFLY_MANAGEMENT_PORT)"
HTTP_PORT_VALUE="${HTTP_PORT_VALUE:-8080}"
MANAGEMENT_PORT_VALUE="${MANAGEMENT_PORT_VALUE:-9990}"

if [[ ! -x "$WILDFLY9_HOME_VALUE/bin/standalone.sh" ||
      ! -x "$WILDFLY9_HOME_VALUE/bin/jboss-cli.sh" ]]; then
  printf 'FALHA: WILDFLY9_HOME não aponta para uma distribuição completa\n' >&2
  exit 1
fi
if [[ ! -f "$WILDFLY9_ARCHIVE_VALUE" ]]; then
  printf 'FALHA: WILDFLY9_ARCHIVE não foi fornecido\n' >&2
  exit 1
fi

expected_wildfly_checksum="$(
  awk -F '\t' '$1 == "wildfly" { print $6 }' \
    "$REPOSITORY_ROOT/runtime/legacy/runtime-manifest.tsv"
)"
actual_wildfly_checksum="$(
  sha256sum "$WILDFLY9_ARCHIVE_VALUE" | awk '{print $1}'
)"
if [[ "$actual_wildfly_checksum" != "$expected_wildfly_checksum" ]]; then
  printf 'FALHA: checksum do WildFly 9 diverge do manifesto\n' >&2
  exit 1
fi

case "$HTTP_PORT_VALUE:$MANAGEMENT_PORT_VALUE" in
  *[!0-9:]*|:|*::*)
    printf 'FALHA: portas do WildFly são inválidas\n' >&2
    exit 1
    ;;
esac
if [[ "$HTTP_PORT_VALUE" == "$MANAGEMENT_PORT_VALUE" ]]; then
  printf 'FALHA: portas HTTP e management devem ser diferentes\n' >&2
  exit 1
fi

if [[ "$PROFILE" == "ci-h2" ]]; then
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_PORTABLE_HOME)"
  H2_JAR_VALUE="$(configuration_value H2_JAR)"
  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" || ! -f "$H2_JAR_VALUE" ]]; then
    printf 'FALHA: Java portátil e H2 são obrigatórios para ci-h2\n' >&2
    exit 1
  fi
  expected_driver_checksum="$(
    awk -F '\t' '$1 == "h2" { print $6 }' \
      "$REPOSITORY_ROOT/runtime/legacy/portable-runtime-manifest.tsv"
  )"
  actual_driver_checksum="$(sha256sum "$H2_JAR_VALUE" | awk '{print $1}')"
  if [[ "$actual_driver_checksum" != "$expected_driver_checksum" ]]; then
    printf 'FALHA: checksum do H2 diverge do manifesto portátil\n' >&2
    exit 1
  fi
  PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/ci-h2.cli"
else
  SELECTED_JAVA_HOME="$(configuration_value JAVA7_HOME)"
  OJDBC7_JAR_VALUE="$(configuration_value OJDBC7_JAR)"
  OJDBC7_SHA256_VALUE="$(configuration_value OJDBC7_SHA256)"
  ORACLE_DB_URL_VALUE="$(configuration_value ORACLE_DB_URL)"
  ORACLE_DB_USER_VALUE="$(configuration_value ORACLE_DB_USER)"
  ORACLE_DB_PASSWORD_VALUE="$(configuration_value ORACLE_DB_PASSWORD)"

  if [[ ! -x "$SELECTED_JAVA_HOME/bin/java" ||
        ! -f "$OJDBC7_JAR_VALUE" ||
        -z "$ORACLE_DB_URL_VALUE" ||
        -z "$ORACLE_DB_USER_VALUE" ||
        -z "$ORACLE_DB_PASSWORD_VALUE" ]]; then
    printf 'FALHA: Java 7u80, ojdbc7 e configuração Oracle são obrigatórios\n' >&2
    exit 1
  fi
  actual_ojdbc7_checksum="$(
    sha256sum "$OJDBC7_JAR_VALUE" | awk '{print $1}'
  )"
  if [[ ! "$OJDBC7_SHA256_VALUE" =~ ^[[:xdigit:]]{64}$ ]] ||
     [[ "$actual_ojdbc7_checksum" != "${OJDBC7_SHA256_VALUE,,}" ]]; then
    printf 'FALHA: checksum do ojdbc7 não foi aprovado\n' >&2
    exit 1
  fi
  PROFILE_FILE="$REPOSITORY_ROOT/runtime/legacy/profiles/oracle.cli"
fi

TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-datasource.XXXXXXXX")"
RUNTIME_HOME="$TEMP_DIRECTORY/wildfly-9.0.2.Final"
install -d -m 0755 "$RUNTIME_HOME"
cp -a "$WILDFLY9_HOME_VALUE/." "$RUNTIME_HOME/"
install -d -m 0755 "$RUNTIME_HOME/standalone/log"

if [[ "$PROFILE" == "ci-h2" ]]; then
  module_directory="$RUNTIME_HOME/modules/com/h2database/h2/cp1d/main"
  install -d -m 0755 "$module_directory"
  install -m 0644 "$H2_JAR_VALUE" "$module_directory/h2-1.4.200.jar"
  install -m 0644 "$REPOSITORY_ROOT/runtime/legacy/h2/module.xml" \
    "$module_directory/module.xml"
else
  module_directory="$RUNTIME_HOME/modules/com/oracle/ojdbc7/main"
  install -d -m 0755 "$module_directory"
  install -m 0644 "$OJDBC7_JAR_VALUE" "$module_directory/ojdbc7.jar"
  install -m 0644 \
    "$REPOSITORY_ROOT/runtime/legacy/ojdbc7/module.xml.template" \
    "$module_directory/module.xml"
fi

SELECTED_MANAGEMENT_PORT="$MANAGEMENT_PORT_VALUE"

if [[ "$PROFILE" == "ci-h2" ]]; then
  JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/standalone.sh" \
      -b 127.0.0.1 \
      -bmanagement 127.0.0.1 \
      -Djboss.http.port="$HTTP_PORT_VALUE" \
      -Djboss.management.http.port="$MANAGEMENT_PORT_VALUE" \
      -Dmigration.bootstrap.h2=true \
      >"$TEMP_DIRECTORY/server.log" 2>&1 &
else
  ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
  ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
  ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
  JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/standalone.sh" \
      -b 127.0.0.1 \
      -bmanagement 127.0.0.1 \
      -Djboss.http.port="$HTTP_PORT_VALUE" \
      -Djboss.management.http.port="$MANAGEMENT_PORT_VALUE" \
      >"$TEMP_DIRECTORY/server.log" 2>&1 &
fi
SERVER_PID="$!"

ready=false
for unused in $(seq 1 60); do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    break
  fi
  if JAVA_HOME="$SELECTED_JAVA_HOME" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
      --commands=':read-attribute(name=server-state)' \
      >/dev/null 2>&1; then
    ready=true
    SERVER_STARTED=true
    break
  fi
  sleep 1
done

if [[ "$ready" != true ]]; then
  printf 'FALHA: WildFly 9 não iniciou no tempo esperado\n' >&2
  if [[ "$PROFILE" == "ci-h2" && -f "$TEMP_DIRECTORY/server.log" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/server.log" |
      sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
  elif [[ -f "$TEMP_DIRECTORY/server.log" ]]; then
    tail -n 40 "$TEMP_DIRECTORY/server.log" |
      sanitize_oracle_output >&2
  else
    printf 'Log do WildFly indisponível para diagnóstico sanitizado\n' >&2
  fi
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --file="$PROFILE_FILE" >"$TEMP_DIRECTORY/profile.out" 2>&1; then
  printf 'FALHA: não foi possível aplicar o perfil %s\n' "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/profile.out" |
      sanitize_oracle_output >&2
  fi
  exit 1
fi

if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
    "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
    --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
    --commands='/subsystem=datasources/data-source=MigrationDS:test-connection-in-pool' \
    >"$TEMP_DIRECTORY/test.out" 2>&1; then
  printf 'FALHA: teste do datasource %s não concluiu\n' "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/test.out" |
      sanitize_oracle_output >&2
  fi
  exit 1
fi

if ! grep -Fq '"outcome" => "success"' "$TEMP_DIRECTORY/test.out" ||
   ! grep -Eq '"result" => (\[true\]|true)' "$TEMP_DIRECTORY/test.out"; then
  printf 'FALHA: pool MigrationDS não confirmou uma conexão no perfil %s\n' \
    "$PROFILE" >&2
  if [[ "$PROFILE" == "oracle" ]]; then
    tail -n 30 "$TEMP_DIRECTORY/test.out" |
      sanitize_oracle_output >&2
  fi
  exit 1
fi

configuration="$RUNTIME_HOME/standalone/configuration/standalone.xml"
if [[ "$PROFILE" == "ci-h2" ]]; then
  if grep -Eiq 'jdbc:h2:(tcp|ssl)|AUTO_SERVER|createTcpServer|createWebServer' \
      "$configuration" ||
     grep -Eiq '<(user-name|password)>[^<]+' "$configuration"; then
    printf 'FALHA: perfil H2 expôs listener, console ou credencial\n' >&2
    exit 1
  fi
else
  for expression in \
    '${env.ORACLE_DB_URL}' \
    '${env.ORACLE_DB_USER}' \
    '${env.ORACLE_DB_PASSWORD}'; do
    if ! grep -Fq "$expression" "$configuration"; then
      printf 'FALHA: configuração Oracle não preservou expressões externas\n' >&2
      exit 1
    fi
  done
fi

if [[ -n "$WAR_FILE" ]]; then
  if ! JAVA_HOME="$SELECTED_JAVA_HOME" \
      "$RUNTIME_HOME/bin/jboss-cli.sh" --connect \
      --controller="127.0.0.1:$MANAGEMENT_PORT_VALUE" \
      --commands="deploy $WAR_FILE --force" \
      >"$TEMP_DIRECTORY/deploy.out" 2>&1; then
    printf 'FALHA: WAR não pôde ser implantado no perfil %s\n' "$PROFILE" >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 40 "$TEMP_DIRECTORY/deploy.out" |
        sanitize_oracle_output >&2
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 40 "$TEMP_DIRECTORY/deploy.out" >&2
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi

  base_url="http://127.0.0.1:$HTTP_PORT_VALUE/wildfly-migration"
  headers="$TEMP_DIRECTORY/headers.out"
  body="$TEMP_DIRECTORY/body.out"
  cookies="$TEMP_DIRECTORY/cookies.txt"
  application_ready=false
  for unused in $(seq 1 45); do
    if curl --silent --show-error --fail \
        --dump-header "$headers" \
        --output "$body" \
        "$base_url/health" &&
       grep -Fq 'status=UP' "$body"; then
      application_ready=true
      break
    fi
    sleep 1
  done
  if [[ "$application_ready" != true ]]; then
    printf 'FALHA: aplicação não ficou saudável no perfil %s\n' "$PROFILE" >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 60 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi
  if ! grep -Eiq '^X-Correlation-ID: [A-Za-z0-9._-]+' "$headers"; then
    printf 'FALHA: resposta não publicou X-Correlation-ID válido\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos" ||
     ! grep -Fq 'data-page="pedidos-lista"' "$body" ||
     ! grep -Fq 'LAB-0001' "$body"; then
    printf 'FALHA: listagem JSP/JSTL não exibiu o seed esperado\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos/novo" ||
     ! grep -Fq 'data-page="pedidos-formulario"' "$body"; then
    printf 'FALHA: formulário de pedido não foi renderizado\n' >&2
    exit 1
  fi

  smoke_number="LAB-SMOKE-$(date +%s)-$SERVER_PID"
  if [[ "$PROFILE" == "oracle" ]]; then
    ORACLE_SMOKE_CREATED=true
  fi
  detail_url=""
  if ! detail_url="$(curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --data-urlencode "numero=$smoke_number" \
      --data-urlencode 'clienteNome=Cliente smoke' \
      --data-urlencode 'descricao=Pedido criado pelo smoke CP-1E' \
      --data-urlencode 'valorTotal=19.75' \
      --output "$body" \
      --write-out '%{url_effective}' \
      "$base_url/pedidos")" ||
     ! grep -Fq 'data-page="pedido-detalhe"' "$body" ||
     ! grep -Fq "$smoke_number" "$body" ||
     ! grep -Fq 'Cliente smoke' "$body"; then
    printf 'FALHA: criação e consulta do pedido não concluíram\n' >&2
    exit 1
  fi

  case "$detail_url" in
    "$base_url"/pedidos/detalhe?id=*)
      smoke_id="${detail_url##*id=}"
      smoke_id="${smoke_id%%&*}"
      ;;
    *)
      printf 'FALHA: redirect do pedido não informou o identificador\n' >&2
      exit 1
      ;;
  esac
  if [[ ! "$smoke_id" =~ ^[1-9][0-9]*$ ]]; then
    printf 'FALHA: identificador criado não é positivo\n' >&2
    exit 1
  fi

  upload_file="$TEMP_DIRECTORY/upload-smoke.txt"
  printf 'conteúdo portátil do upload CP-1F\n' >"$upload_file"
  upload_size="$(wc -c <"$upload_file" | tr -d '[:space:]')"
  upload_sha256="$(sha256sum "$upload_file" | awk '{print $1}')"
  if ! curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --form "arquivo=@$upload_file;filename=../upload-smoke.txt;type=text/plain" \
      --output "$body" \
      "$base_url/anexos/upload?pedidoId=$smoke_id" ||
     ! grep -Fq 'data-upload-status="ok"' "$body" ||
     ! grep -Fq 'data-anexo-nome="upload-smoke.txt"' "$body" ||
     ! grep -Fq '>text/plain</td>' "$body" ||
     ! grep -Fq ">$upload_size</td>" "$body" ||
     ! grep -Fq "$upload_sha256" "$body"; then
    printf 'FALHA: upload e metadados comparáveis não concluíram\n' >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi

  oversized_file="$TEMP_DIRECTORY/upload-oversized.bin"
  dd if=/dev/zero of="$oversized_file" \
    bs=1024 count=512 status=none
  printf 'x' >>"$oversized_file"
  oversized_status=""
  if ! oversized_status="$(curl --silent --show-error \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --form "arquivo=@$oversized_file;filename=oversized.bin;type=application/octet-stream" \
      --output "$body" \
      --write-out '%{http_code}' \
      "$base_url/anexos/upload?pedidoId=$smoke_id")"; then
    printf 'FALHA: cenário negativo do limite de upload não respondeu\n' >&2
    exit 1
  fi
  if [[ "$oversized_status" != "413" ]] ||
     ! grep -Fq 'data-page="erro-controlado"' "$body" ||
     ! grep -Fq 'excede o limite de 512 KiB' "$body"; then
    printf 'FALHA: arquivo acima do limite não foi rejeitado com HTTP 413\n' >&2
    exit 1
  fi

  xml_number="LAB-SMOKE-XML-$(date +%s)-$SERVER_PID"
  valid_xml="$TEMP_DIRECTORY/pedido-valido.xml"
  sed "s/XML-0001/$xml_number/" \
    "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
    >"$valid_xml"
  xml_detail_url=""
  if ! xml_detail_url="$(curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --header 'Content-Type: application/xml' \
      --data-binary "@$valid_xml" \
      --output "$body" \
      --write-out '%{url_effective}' \
      "$base_url/pedidos/importar-xml")" ||
     ! grep -Fq 'data-xml-import-status="ok"' "$body" ||
     ! grep -Fq "$xml_number" "$body" ||
     ! grep -Fq 'Cliente XML' "$body" ||
     ! grep -Eq '>349[,.]9(0)?<' "$body"; then
    printf 'FALHA: importação XML válida não criou pedido equivalente\n' >&2
    grep -Fq 'data-xml-import-status="ok"' "$body" ||
      printf 'FALHA: marcador de sucesso XML ausente\n' >&2
    grep -Fq "$xml_number" "$body" ||
      printf 'FALHA: número importado ausente no detalhe\n' >&2
    grep -Fq 'Cliente XML' "$body" ||
      printf 'FALHA: cliente importado ausente no detalhe\n' >&2
    grep -Eq '>349[,.]9(0)?<' "$body" ||
      printf 'FALHA: valor importado ausente no detalhe\n' >&2
    if [[ "$PROFILE" == "oracle" ]]; then
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sanitize_oracle_output >&2
    else
      tail -n 80 "$TEMP_DIRECTORY/server.log" |
        sed "s#${TEMP_DIRECTORY}#<runtime-temporario>#g" >&2
    fi
    exit 1
  fi
  case "$xml_detail_url" in
    "$base_url"/pedidos/detalhe?id=*"&importacao=ok")
      ;;
    *)
      printf 'FALHA: redirect da importação XML não preservou o contrato\n' >&2
      exit 1
      ;;
  esac

  for hostile_fixture in \
    pedido-invalido-xsd.xml \
    pedido-xxe.xml \
    pedido-entidades-expansivas.xml; do
    xml_status=""
    if ! xml_status="$(curl --silent --show-error \
        --cookie-jar "$cookies" \
        --cookie "$cookies" \
        --header 'Content-Type: application/xml' \
        --data-binary \
          "@$REPOSITORY_ROOT/contract-tests/fixtures/xml/$hostile_fixture" \
        --output "$body" \
        --write-out '%{http_code}' \
        "$base_url/pedidos/importar-xml")"; then
      printf 'FALHA: cenário XML negativo não respondeu: %s\n' \
        "$hostile_fixture" >&2
      exit 1
    fi
    if [[ "$xml_status" != "400" ]] ||
       ! grep -Fq 'data-page="erro-controlado"' "$body"; then
      printf 'FALHA: fixture XML deveria ser rejeitada com HTTP 400: %s\n' \
        "$hostile_fixture" >&2
      exit 1
    fi
  done

  if ! curl --silent --show-error --fail \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --output "$body" \
      "$base_url/pedidos" ||
     grep -Fq 'XML INVÁLIDO COM ESPAÇOS' "$body" ||
     grep -Fq 'XML-XXE-0001' "$body" ||
     grep -Fq 'XML-ENTITY-0001' "$body"; then
    printf 'FALHA: XML rejeitado deixou persistência parcial\n' >&2
    exit 1
  fi

  if ! curl --silent --show-error --fail --location \
      --cookie-jar "$cookies" \
      --cookie "$cookies" \
      --data-urlencode 'modoExibicao=COMPACTO' \
      --output "$body" \
      "$base_url/preferencia" ||
     ! grep -Fq 'data-display-mode="COMPACTO"' "$body"; then
    printf 'FALHA: preferência não persistiu na HttpSession\n' >&2
    exit 1
  fi

  if [[ "$PROFILE" == "oracle" ]]; then
    if ! ORACLE_DB_URL="$ORACLE_DB_URL_VALUE" \
        ORACLE_DB_USER="$ORACLE_DB_USER_VALUE" \
        ORACLE_DB_PASSWORD="$ORACLE_DB_PASSWORD_VALUE" \
        "$REPOSITORY_ROOT/scripts/oracle-lab-schema.sh" \
          cleanup-smokes --env "$ENV_FILE" \
          >"$TEMP_DIRECTORY/cleanup.out" 2>&1; then
      printf 'FALHA: dados transitórios do smoke Oracle não foram limpos\n' >&2
      exit 1
    fi
    ORACLE_SMOKE_CREATED=false
  fi

  printf 'OK: fluxo web %s validou pedidos, sessão, upload e importação XML\n' \
    "$PROFILE"
fi

printf 'OK: datasource %s publicou java:/jdbc/MigrationDS e passou no pool em loopback\n' \
  "$PROFILE"

if [[ "$MANUAL_MODE" == true ]]; then
  printf '\nAplicação legada disponível somente em loopback:\n'
  printf '  Lista:  http://127.0.0.1:%s/wildfly-migration/pedidos\n' \
    "$HTTP_PORT_VALUE"
  printf '  Novo:   http://127.0.0.1:%s/wildfly-migration/pedidos/novo\n' \
    "$HTTP_PORT_VALUE"
  printf '  Saúde:  http://127.0.0.1:%s/wildfly-migration/health\n' \
    "$HTTP_PORT_VALUE"
  printf '\nLog bruto do WildFly:\n'
  printf '  Arquivo: %s\n' "$TEMP_DIRECTORY/server.log"
  printf '  Acompanhar: tail -f -- %q\n' "$TEMP_DIRECTORY/server.log"
  if [[ "$PROFILE" == "oracle" ]]; then
    printf '  ATENÇÃO: revise host, serviço, usuário e URL interna antes de compartilhar este log.\n'
  fi
  printf 'Use outro terminal ou navegador para os testes. Ctrl+C encerra e limpa o runtime temporário.\n'

  while kill -0 "$SERVER_PID" >/dev/null 2>&1; do
    sleep 5
  done
  printf 'FALHA: WildFly encerrou durante a sessão manual\n' >&2
  exit 1
fi
