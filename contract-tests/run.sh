#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL=""
PROFILE=""
WAR_FILE=""
RESULT_FILE=""
COMMIT_SHA=""
RUNTIME=""
CORRELATION_ID=""
TEMP_DIRECTORY=""

usage() {
  cat <<'USAGE'
Uso:
  ./contract-tests/run.sh \
    --base-url URL \
    --profile ci-h2|oracle \
    --war ARQUIVO \
    --result ARQUIVO \
    --commit SHA \
    --runtime IDENTIFICADOR \
    --correlation-id IDENTIFICADOR

A suíte usa somente HTTP, HTML e arquivos externos; não carrega classes do WAR.
O relatório não registra URL, endereço interno, usuário ou credencial.
USAGE
}

fail() {
  printf 'FALHA contrato externo: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_DIRECTORY" ]]; then
    case "$TEMP_DIRECTORY" in
      "${TMPDIR:-/tmp}"/wildfly-migration-contracts.*)
        rm -rf -- "$TEMP_DIRECTORY"
        ;;
      *)
        printf 'AVISO: diretório temporário inesperado não foi removido\n' >&2
        ;;
    esac
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)
      [[ $# -ge 2 ]] || fail "--base-url exige um valor"
      BASE_URL="${2%/}"
      shift 2
      ;;
    --profile)
      [[ $# -ge 2 ]] || fail "--profile exige um valor"
      PROFILE="$2"
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
    --commit)
      [[ $# -ge 2 ]] || fail "--commit exige um SHA"
      COMMIT_SHA="$2"
      shift 2
      ;;
    --runtime)
      [[ $# -ge 2 ]] || fail "--runtime exige um identificador"
      RUNTIME="$2"
      shift 2
      ;;
    --correlation-id)
      [[ $# -ge 2 ]] || fail "--correlation-id exige um identificador"
      CORRELATION_ID="$2"
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

case "$PROFILE" in
  ci-h2)
    QUALIFICATION="portable-ci"
    ;;
  oracle)
    QUALIFICATION="oracle-qualified"
    ;;
  *)
    fail "perfil deve ser ci-h2 ou oracle"
    ;;
esac

case "$BASE_URL" in
  http://*|https://*)
    ;;
  *)
    fail "URL base deve usar HTTP ou HTTPS"
    ;;
esac

[[ -f "$WAR_FILE" ]] || fail "WAR informado não existe"
[[ -n "$RESULT_FILE" ]] || fail "arquivo de resultado não informado"
[[ "$COMMIT_SHA" =~ ^[0-9a-f]{7,40}$ ]] ||
  fail "commit deve ser um SHA hexadecimal"
[[ "$RUNTIME" =~ ^[A-Za-z0-9._-]{1,80}$ ]] ||
  fail "identificador de runtime inválido"
[[ "$CORRELATION_ID" =~ ^[A-Za-z0-9._-]{1,64}$ ]] ||
  fail "identificador de correlação inválido"

for command_name in curl grep sed sha256sum dd awk wc tr; do
  command -v "$command_name" >/dev/null 2>&1 ||
    fail "comando obrigatório ausente: $command_name"
done

TEMP_DIRECTORY="$(
  mktemp -d "${TMPDIR:-/tmp}/wildfly-migration-contracts.XXXXXXXX"
)"
HEADERS="$TEMP_DIRECTORY/headers.out"
BODY="$TEMP_DIRECTORY/body.out"
COOKIES="$TEMP_DIRECTORY/cookies.txt"

if ! curl --silent --show-error --fail \
    --connect-timeout 5 \
    --max-time 10 \
    --dump-header "$HEADERS" \
    --output "$BODY" \
    "$BASE_URL/health" ||
   ! grep -Fq 'status=UP' "$BODY"; then
  fail "aplicação indisponível na verificação inicial"
fi
grep -Eiq '^X-Correlation-ID: [A-Za-z0-9._-]+' "$HEADERS" ||
  fail "health não publicou correlação válida"

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos" ||
   ! grep -Fq 'data-page="pedidos-lista"' "$BODY" ||
   ! grep -Fq 'LAB-0001' "$BODY"; then
  fail "listagem não exibiu o seed esperado"
fi

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos/novo" ||
   ! grep -Fq 'data-page="pedidos-formulario"' "$BODY"; then
  fail "formulário de criação não foi renderizado"
fi

RUN_SUFFIX="$(date +%s)-$$"
ORDER_NUMBER="LAB-SMOKE-C-$RUN_SUFFIX"
DETAIL_URL=""
if ! DETAIL_URL="$(curl --silent --show-error --fail --location \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --data-urlencode "numero=$ORDER_NUMBER" \
    --data-urlencode 'clienteNome=Cliente contrato' \
    --data-urlencode 'descricao=Pedido criado pela suíte externa' \
    --data-urlencode 'valorTotal=19.75' \
    --output "$BODY" \
    --write-out '%{url_effective}' \
    "$BASE_URL/pedidos")" ||
   ! grep -Fq 'data-page="pedido-detalhe"' "$BODY" ||
   ! grep -Fq "$ORDER_NUMBER" "$BODY" ||
   ! grep -Fq 'Cliente contrato' "$BODY"; then
  fail "criação e detalhe do pedido não concluíram"
fi

case "$DETAIL_URL" in
  "$BASE_URL"/pedidos/detalhe?id=*)
    ORDER_ID="${DETAIL_URL##*id=}"
    ORDER_ID="${ORDER_ID%%&*}"
    ;;
  *)
    fail "redirect da criação não informou o identificador"
    ;;
esac
[[ "$ORDER_ID" =~ ^[1-9][0-9]*$ ]] ||
  fail "identificador persistido não é positivo"

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos/detalhe?id=$ORDER_ID" ||
   ! grep -Fq "$ORDER_NUMBER" "$BODY" ||
   ! grep -Fq 'Cliente contrato' "$BODY"; then
  fail "estado persistido do pedido não foi recuperado por nova requisição"
fi

UPLOAD_FILE="$TEMP_DIRECTORY/contrato-upload.txt"
printf 'conteúdo portátil da suíte externa CP-1F\n' >"$UPLOAD_FILE"
UPLOAD_SIZE="$(wc -c <"$UPLOAD_FILE" | tr -d '[:space:]')"
UPLOAD_SHA256="$(sha256sum "$UPLOAD_FILE" | awk '{print $1}')"
if ! curl --silent --show-error --fail --location \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --form \
      "arquivo=@$UPLOAD_FILE;filename=../contrato-upload.txt;type=text/plain" \
    --output "$BODY" \
    "$BASE_URL/anexos/upload?pedidoId=$ORDER_ID" ||
   ! grep -Fq 'data-upload-status="ok"' "$BODY" ||
   ! grep -Fq 'data-anexo-nome="contrato-upload.txt"' "$BODY" ||
   ! grep -Fq '>text/plain</td>' "$BODY" ||
   ! grep -Fq ">$UPLOAD_SIZE</td>" "$BODY" ||
   ! grep -Fq "$UPLOAD_SHA256" "$BODY"; then
  fail "upload e metadados comparáveis não concluíram"
fi

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos/detalhe?id=$ORDER_ID" ||
   ! grep -Fq 'data-anexo-nome="contrato-upload.txt"' "$BODY" ||
   ! grep -Fq "$UPLOAD_SHA256" "$BODY"; then
  fail "metadados persistidos do upload não foram recuperados"
fi

OVERSIZED_FILE="$TEMP_DIRECTORY/upload-oversized.bin"
dd if=/dev/zero of="$OVERSIZED_FILE" bs=1024 count=512 status=none
printf 'x' >>"$OVERSIZED_FILE"
UPLOAD_LIMIT_STATUS="$(
  curl --silent --show-error \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --form \
      "arquivo=@$OVERSIZED_FILE;filename=oversized.bin;type=application/octet-stream" \
    --output "$BODY" \
    --write-out '%{http_code}' \
    "$BASE_URL/anexos/upload?pedidoId=$ORDER_ID"
)" || fail "cenário negativo do upload não respondeu"
if [[ "$UPLOAD_LIMIT_STATUS" != "413" ]] ||
   ! grep -Fq 'data-page="erro-controlado"' "$BODY"; then
  fail "upload acima do limite não retornou HTTP 413"
fi

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos/importar-xml" ||
   ! grep -Fq 'data-page="pedidos-importacao-xml"' "$BODY" ||
   ! grep -Fq 'name="arquivoXml"' "$BODY"; then
  fail "página de seleção do XML não foi renderizada"
fi

XML_NUMBER="LAB-SMOKE-X-$RUN_SUFFIX"
VALID_XML="$TEMP_DIRECTORY/pedido-valido.xml"
sed "s/XML-0001/$XML_NUMBER/" \
  "$REPOSITORY_ROOT/contract-tests/fixtures/xml/pedido-valido.xml" \
  >"$VALID_XML"
XML_DETAIL_URL=""
if ! XML_DETAIL_URL="$(curl --silent --show-error --fail --location \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --header "X-Correlation-ID: $CORRELATION_ID" \
    --form "arquivoXml=@$VALID_XML;type=application/xml" \
    --output "$BODY" \
    --write-out '%{url_effective}' \
    "$BASE_URL/pedidos/importar-xml")" ||
   ! grep -Fq 'data-xml-import-status="ok"' "$BODY" ||
   ! grep -Fq "$XML_NUMBER" "$BODY" ||
   ! grep -Fq 'Cliente XML' "$BODY" ||
   ! grep -Eq '>349[,.]9(0)?<' "$BODY"; then
  fail "importação XML válida não criou pedido equivalente"
fi
case "$XML_DETAIL_URL" in
  "$BASE_URL"/pedidos/detalhe?id=*"&importacao=ok")
    ;;
  *)
    fail "redirect da importação XML divergiu"
    ;;
esac

VALIDATOR_XML="$REPOSITORY_ROOT/contract-tests/fixtures/xml/"
VALIDATOR_XML="${VALIDATOR_XML}pedido-invalido-validador.xml"
XML_VALIDATOR_STATUS="$(
  curl --silent --show-error \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --header "X-Correlation-ID: $CORRELATION_ID" \
    --header 'Content-Type: application/xml' \
    --data-binary "@$VALIDATOR_XML" \
    --output "$BODY" \
    --write-out '%{http_code}' \
    "$BASE_URL/pedidos/importar-xml"
)" || fail "cenário de rejeição pelo validador não respondeu"
if [[ "$XML_VALIDATOR_STATUS" != "400" ]] ||
   ! grep -Fq 'data-page="erro-controlado"' "$BODY" ||
   ! grep -Fq 'deve iniciar com status NOVO' "$BODY"; then
  fail "XML válido no XSD não foi rejeitado pela regra de status inicial"
fi

for HOSTILE_FIXTURE in \
  pedido-invalido-xsd.xml \
  pedido-xxe.xml \
  pedido-entidades-expansivas.xml; do
  XML_STATUS="$(
    curl --silent --show-error \
      --cookie-jar "$COOKIES" \
      --cookie "$COOKIES" \
      --header 'Content-Type: application/xml' \
      --data-binary \
        "@$REPOSITORY_ROOT/contract-tests/fixtures/xml/$HOSTILE_FIXTURE" \
      --output "$BODY" \
      --write-out '%{http_code}' \
      "$BASE_URL/pedidos/importar-xml"
  )" || fail "cenário XML negativo não respondeu"
  if [[ "$XML_STATUS" != "400" ]] ||
     ! grep -Fq 'data-page="erro-controlado"' "$BODY"; then
    fail "fixture XML hostil não retornou HTTP 400"
  fi
done

if ! curl --silent --show-error --fail \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --output "$BODY" \
    "$BASE_URL/pedidos" ||
   ! grep -Fq "$ORDER_NUMBER" "$BODY" ||
   ! grep -Fq "$XML_NUMBER" "$BODY" ||
   grep -Fq 'XML INVÁLIDO COM ESPAÇOS' "$BODY" ||
   grep -Fq 'XML-VALIDATOR-0001' "$BODY" ||
   grep -Fq 'XML-XXE-0001' "$BODY" ||
   grep -Fq 'XML-ENTITY-0001' "$BODY"; then
  fail "estado final divergiu ou XML rejeitado deixou persistência parcial"
fi

if ! curl --silent --show-error --fail --location \
    --cookie-jar "$COOKIES" \
    --cookie "$COOKIES" \
    --data-urlencode 'modoExibicao=COMPACTO' \
    --output "$BODY" \
    "$BASE_URL/preferencia" ||
   ! grep -Fq 'data-display-mode="COMPACTO"' "$BODY"; then
  fail "preferência não persistiu na HttpSession"
fi

WAR_SHA256="$(sha256sum "$WAR_FILE" | awk '{print $1}')"
RESULT_DIRECTORY="$(dirname "$RESULT_FILE")"
install -d -m 0755 "$RESULT_DIRECTORY"
RESULT_TEMPORARY="$RESULT_FILE.tmp.$$"
{
  printf '{\n'
  printf '  "schema": "wildfly-migration-contract-result/v1",\n'
  printf '  "qualification": "%s",\n' "$QUALIFICATION"
  printf '  "profile": "%s",\n' "$PROFILE"
  printf '  "commit": "%s",\n' "$COMMIT_SHA"
  printf '  "warSha256": "%s",\n' "$WAR_SHA256"
  printf '  "runtime": "%s",\n' "$RUNTIME"
  printf '  "scenarios": {\n'
  printf '    "health": "passed",\n'
  printf '    "list": "passed",\n'
  printf '    "create": "passed",\n'
  printf '    "detail": "passed",\n'
  printf '    "session": "passed",\n'
  printf '    "upload": "passed",\n'
  printf '    "uploadLimit": "passed",\n'
  printf '    "xmlForm": "passed",\n'
  printf '    "xmlValid": "passed",\n'
  printf '    "xmlInvalidXsd": "passed",\n'
  printf '    "xmlValidatorRejected": "passed",\n'
  printf '    "xmlXxe": "passed",\n'
  printf '    "xmlEntityExpansion": "passed",\n'
  printf '    "persistedState": "passed"\n'
  printf '  }\n'
  printf '}\n'
} >"$RESULT_TEMPORARY"
mv "$RESULT_TEMPORARY" "$RESULT_FILE"

printf 'OK: contratos externos %s concluíram; relatório sanitizado: %s\n' \
  "$PROFILE" "$RESULT_FILE"
