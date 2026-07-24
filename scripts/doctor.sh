#!/usr/bin/env bash

set -uo pipefail

CHECKPOINT="${MIGRATION_CHECKPOINT:-CP-1A}"
CHECKPOINT_EXPLICIT=false
ENV_FILE=""
CI_MODE=false
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
SKIP_COUNT=0

usage() {
  cat <<'USAGE'
Uso:
  ./scripts/doctor.sh [CHECKPOINT] [--env ARQUIVO] [--ci]

Exemplos:
  ./scripts/doctor.sh CP-1A
  ./scripts/doctor.sh CP-1B --env .env
  ./scripts/doctor.sh CP-3J --env .env

Opções:
  --env ARQUIVO  Carrega pares simples NOME=VALOR sem executar o arquivo.
  --ci           Valida somente o bootstrap portável do repositório.
  -h, --help     Mostra esta ajuda.
USAGE
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'OK           %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FALHA        %s\n' "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf 'AVISO        %s\n' "$1"
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf 'NÃO EXIGIDO  %s\n' "$1"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_env_file() {
  local file="$1"
  local line key value line_number=0

  if [[ ! -f "$file" ]]; then
    fail "arquivo de ambiente não encontrado: $file"
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      fail "linha $line_number inválida em $file"
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"
    value="$(trim "$value")"

    case "$key" in
      MIGRATION_CHECKPOINT|LAB_BIND_ADDRESS|WILDFLY_HTTP_PORT|WILDFLY_MANAGEMENT_PORT|\
      JAVA7_HOME|JAVA7_ARCHIVE|JAVA7_ARCHIVE_SHA256|\
      JAVA8_HOME|JAVA8_ARCHIVE|JAVA8_ARCHIVE_SHA256|\
      JAVA17_HOME|JAVA17_ARCHIVE|JAVA17_ARCHIVE_SHA256|\
      JAVA21_HOME|JAVA21_ARCHIVE|JAVA21_ARCHIVE_SHA256|\
      JAVA25_HOME|JAVA25_ARCHIVE|JAVA25_ARCHIVE_SHA256|\
      MAVEN_HOME|\
      WILDFLY9_HOME|WILDFLY9_ARCHIVE|WILDFLY9_ARCHIVE_SHA256|\
      WILDFLY26_HOME|WILDFLY26_ARCHIVE|WILDFLY26_ARCHIVE_SHA256|\
      WILDFLY41_HOME|WILDFLY41_ARCHIVE|WILDFLY41_ARCHIVE_SHA256|\
      ORACLE_DB_URL|ORACLE_DB_USER|ORACLE_DB_PASSWORD|ORACLE_DB_WALLET)
        ;;
      *)
        fail "variável não permitida na linha $line_number de $file: $key"
        continue
        ;;
    esac

    if [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
      value="${value:1:${#value}-2}"
    fi

    printf -v "$key" '%s' "$value"
    export "$key"
  done < "$file"

  pass "configuração carregada de $file sem executar comandos"
}

checkpoint_rank() {
  case "$1" in
    CP-1A) printf '10' ;;
    CP-1B) printf '11' ;;
    CP-1C) printf '12' ;;
    CP-1D) printf '13' ;;
    CP-1E) printf '14' ;;
    CP-1F) printf '15' ;;
    CP-2A) printf '20' ;;
    CP-2B) printf '21' ;;
    CP-2C) printf '22' ;;
    CP-2D) printf '23' ;;
    CP-3A) printf '30' ;;
    CP-3B) printf '31' ;;
    CP-3C) printf '32' ;;
    CP-3D) printf '33' ;;
    CP-3E) printf '34' ;;
    CP-3F) printf '35' ;;
    CP-3G) printf '36' ;;
    CP-3H) printf '37' ;;
    CP-3I) printf '38' ;;
    CP-3J) printf '39' ;;
    CP-3K) printf '40' ;;
    *) return 1 ;;
  esac
}

rank_at_least() {
  local minimum
  minimum="$(checkpoint_rank "$1")" || return 1
  (( SELECTED_RANK >= minimum ))
}

require_command() {
  local command_name="$1"
  local label="$2"
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "$label disponível"
  else
    fail "$label ausente"
  fi
}

check_required_files() {
  local path
  local required=(
    ".env.example"
    ".gitignore"
    "README.md"
    "CONTRIBUTING.md"
    "SECURITY.md"
    "docs/environment-setup.md"
    "docs/github-workflow.md"
    "docs/checkpoints.md"
    ".github/pull_request_template.md"
    ".github/workflows/validate.yml"
    "scripts/doctor.sh"
  )

  for path in "${required[@]}"; do
    if [[ -f "$path" ]]; then
      pass "arquivo obrigatório presente: $path"
    else
      fail "arquivo obrigatório ausente: $path"
    fi
  done
}

check_repository() {
  require_command git "Git"

  if ! command -v git >/dev/null 2>&1; then
    return
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "diretório é um worktree Git"
  else
    fail "diretório não é um worktree Git"
    return
  fi

  if git check-ignore -q .env 2>/dev/null; then
    pass ".env está ignorado"
  else
    fail ".env não está ignorado"
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    pass "remote origin configurado sem expor sua URL"
  else
    fail "remote origin não configurado"
  fi

  if [[ "$CI_MODE" == true ]]; then
    skip "identidade Git local (execução em CI)"
    skip "autenticação interativa da GitHub CLI (execução em CI)"
  else
    if [[ -n "$(git config --get user.name 2>/dev/null || true)" ]]; then
      pass "user.name do Git configurado"
    else
      fail "user.name do Git não configurado"
    fi

    if [[ -n "$(git config --get user.email 2>/dev/null || true)" ]]; then
      pass "user.email do Git configurado"
    else
      fail "user.email do Git não configurado"
    fi

    require_command gh "GitHub CLI"
    if command -v gh >/dev/null 2>&1; then
      if gh auth status --hostname github.com >/dev/null 2>&1; then
        pass "GitHub CLI autenticada em github.com"
      else
        fail "GitHub CLI sem autenticação válida em github.com"
      fi
    fi
  fi
}

check_sensitive_paths() {
  local found=""
  local tracked=""

  found="$(
    find . -path './.git' -prune -o -type f \
      \( -name '*.pem' -o -name '*.key' -o \
         -name '*.p12' -o -name '*.pfx' -o -name '*.jks' -o \
         -name '*.wallet' -o -name 'ojdbc*.jar' -o \
         -name 'jdk-7u80*' \) -print -quit
  )"

  if [[ -z "$found" ]]; then
    pass "nenhum arquivo local sensível conhecido encontrado"
  else
    fail "arquivo local sensível encontrado; remova-o do checkout"
  fi

  if command -v git >/dev/null 2>&1 &&
     git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked="$(
      git ls-files | awk '
        /(^|\/)\.env$/ ||
        /\.(pem|key|p12|pfx|jks|wallet)$/ ||
        /(^|\/)ojdbc[^/]*\.jar$/ ||
        /(^|\/)jdk-7u80/ { print; exit }
      '
    )"
    if [[ -z "$tracked" ]]; then
      pass "nenhum caminho sensível conhecido está versionado"
    else
      fail "há caminho sensível versionado; inspecione git ls-files"
    fi
  fi
}

check_container_runtime() {
  if command -v docker >/dev/null 2>&1; then
    pass "Docker CLI disponível"
    if docker info >/dev/null 2>&1; then
      pass "Docker daemon acessível"
    else
      fail "Docker daemon não está acessível"
    fi
  elif command -v podman >/dev/null 2>&1; then
    warn "Podman disponível; o checkpoint deve confirmar suporte explícito"
    if podman info >/dev/null 2>&1; then
      pass "Podman runtime acessível"
    else
      fail "Podman runtime não está acessível"
    fi
  else
    fail "nenhum runtime de containers suportado foi encontrado"
  fi
}

check_java() {
  local label="$1"
  local home_variable="$2"
  local expected_pattern="$3"
  local archive_variable="$4"
  local checksum_variable="$5"
  local java_home="${!home_variable:-}"
  local output=""

  if [[ -z "$java_home" ]]; then
    fail "$label: $home_variable não definido"
  elif [[ ! -x "$java_home/bin/java" ]]; then
    fail "$label: executável bin/java ausente no diretório configurado"
  else
    output="$("$java_home/bin/java" -version 2>&1 | head -n 1 || true)"
    if [[ "$output" == *"$expected_pattern"* ]]; then
      pass "$label: versão esperada detectada"
    else
      fail "$label: versão detectada não corresponde a $expected_pattern"
    fi
  fi

  check_archive_checksum "$label" "$archive_variable" "$checksum_variable"
}

check_archive_checksum() {
  local label="$1"
  local archive_variable="$2"
  local checksum_variable="$3"
  local archive="${!archive_variable:-}"
  local expected="${!checksum_variable:-}"
  local actual=""

  if [[ -z "$archive" ]]; then
    fail "$label: $archive_variable não definido"
    return
  fi
  if [[ ! -f "$archive" ]]; then
    fail "$label: arquivo externo não encontrado"
    return
  fi
  if [[ ! "$expected" =~ ^[[:xdigit:]]{64}$ ]]; then
    fail "$label: $checksum_variable deve conter SHA-256 com 64 caracteres"
    return
  fi
  if ! command -v sha256sum >/dev/null 2>&1; then
    fail "$label: sha256sum ausente"
    return
  fi

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "${actual,,}" == "${expected,,}" ]]; then
    pass "$label: checksum SHA-256 aprovado"
  else
    fail "$label: checksum SHA-256 divergente"
  fi
}

check_wildfly() {
  local label="$1"
  local home_variable="$2"
  local expected_version="$3"
  local archive_variable="$4"
  local checksum_variable="$5"
  local wildfly_home="${!home_variable:-}"
  local manifest=""

  if [[ -z "$wildfly_home" ]]; then
    fail "$label: $home_variable não definido"
  elif [[ ! -x "$wildfly_home/bin/standalone.sh" ]]; then
    fail "$label: bin/standalone.sh ausente no diretório configurado"
  else
    manifest="$(
      find "$wildfly_home/modules" -path '*/org/jboss/as/product/*/dir/META-INF/MANIFEST.MF' \
        -type f -print -quit 2>/dev/null
    )"
    if [[ -n "$manifest" ]] && grep -Fq "$expected_version" "$manifest"; then
      pass "$label: versão $expected_version detectada no manifesto"
    else
      fail "$label: não foi possível confirmar a versão $expected_version"
    fi
  fi

  check_archive_checksum "$label" "$archive_variable" "$checksum_variable"
}

check_maven() {
  local maven_command="mvn"
  local output=""

  if [[ -n "${MAVEN_HOME:-}" ]]; then
    maven_command="$MAVEN_HOME/bin/mvn"
  fi

  if [[ ! -x "$maven_command" ]] && ! command -v "$maven_command" >/dev/null 2>&1; then
    fail "Maven: executável não encontrado"
    return
  fi

  output="$("$maven_command" --version 2>/dev/null | head -n 1 || true)"
  if [[ "$output" == *"Apache Maven 3.9.16"* ]]; then
    pass "Maven 3.9.16 detectado"
  else
    fail "Maven 3.9.16 não detectado"
  fi
}

check_oracle_variables() {
  local variable
  local required=(ORACLE_DB_URL ORACLE_DB_USER ORACLE_DB_PASSWORD)

  for variable in "${required[@]}"; do
    if [[ -n "${!variable:-}" ]]; then
      pass "$variable presente (valor oculto)"
    else
      fail "$variable ausente"
    fi
  done

  if [[ -n "${ORACLE_DB_WALLET:-}" ]]; then
    if [[ -e "$ORACLE_DB_WALLET" ]]; then
      pass "ORACLE_DB_WALLET presente e caminho acessível"
    else
      fail "ORACLE_DB_WALLET definido, mas caminho não está acessível"
    fi
  else
    skip "ORACLE_DB_WALLET não configurado; opcional quando a conexão não usa wallet"
  fi
}

check_network_defaults() {
  local bind_address="${LAB_BIND_ADDRESS:-127.0.0.1}"
  local port

  case "$bind_address" in
    127.0.0.1|localhost|::1)
      pass "bind de laboratório restrito a loopback"
      ;;
    *)
      fail "LAB_BIND_ADDRESS deve permanecer em loopback para os runtimes legados"
      ;;
  esac

  for port in "${WILDFLY_HTTP_PORT:-8080}" "${WILDFLY_MANAGEMENT_PORT:-9990}"; do
    if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
      pass "porta configurada é válida: $port"
    else
      fail "porta configurada fora do intervalo TCP válido"
    fi
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      if [[ $# -lt 2 ]]; then
        printf 'FALHA        --env exige um arquivo\n'
        exit 2
      fi
      ENV_FILE="$2"
      shift 2
      ;;
    --ci)
      CI_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'FALHA        opção desconhecida: %s\n' "$1"
      usage
      exit 2
      ;;
    *)
      CHECKPOINT="$1"
      CHECKPOINT_EXPLICIT=true
      shift
      ;;
  esac
done

if [[ -n "$ENV_FILE" ]]; then
  load_env_file "$ENV_FILE"
fi

if [[ "$CHECKPOINT_EXPLICIT" == false ]]; then
  CHECKPOINT="${MIGRATION_CHECKPOINT:-$CHECKPOINT}"
fi

if ! SELECTED_RANK="$(checkpoint_rank "$CHECKPOINT")"; then
  printf 'FALHA        checkpoint inválido: %s\n' "$CHECKPOINT"
  usage
  exit 2
fi

printf 'Doctor do laboratório — checkpoint %s\n\n' "$CHECKPOINT"

check_required_files
check_repository
check_sensitive_paths

if [[ "$CI_MODE" == true ]]; then
  skip "runtimes locais, checksums, variáveis Oracle e portas (execução em CI)"
elif rank_at_least CP-1B; then
  check_container_runtime
  check_network_defaults
  check_java "Java 7u80" JAVA7_HOME '1.7.0_80' JAVA7_ARCHIVE JAVA7_ARCHIVE_SHA256
  check_wildfly "WildFly 9" WILDFLY9_HOME '9.0.2.Final' WILDFLY9_ARCHIVE WILDFLY9_ARCHIVE_SHA256
else
  skip "runtime de containers (entra no CP-1B)"
  skip "portas e bind de runtime (entram no CP-1B)"
  skip "Java 7u80 e checksum (entram no CP-1B)"
  skip "WildFly 9 e checksum (entram no CP-1B)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-1D; then
  check_oracle_variables
else
  skip "variáveis Oracle 19c (entram no CP-1D)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-2A; then
  check_java "OpenJDK 8" JAVA8_HOME '1.8.0' JAVA8_ARCHIVE JAVA8_ARCHIVE_SHA256
else
  skip "OpenJDK 8 e checksum (entram no CP-2A)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-2B; then
  check_wildfly "WildFly 26" WILDFLY26_HOME '26.1.3.Final' WILDFLY26_ARCHIVE WILDFLY26_ARCHIVE_SHA256
else
  skip "WildFly 26 e checksum (entram no CP-2B)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-2C; then
  check_maven
else
  skip "Maven 3.9.16 (entra no CP-2C)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-3A; then
  check_java "OpenJDK 17" JAVA17_HOME 'version \"17' JAVA17_ARCHIVE JAVA17_ARCHIVE_SHA256
else
  skip "OpenJDK 17 e checksum (entram no CP-3A)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-3E; then
  check_java "OpenJDK 21" JAVA21_HOME 'version \"21' JAVA21_ARCHIVE JAVA21_ARCHIVE_SHA256
  check_wildfly "WildFly 41" WILDFLY41_HOME '41.0.0.Final' WILDFLY41_ARCHIVE WILDFLY41_ARCHIVE_SHA256
else
  skip "OpenJDK 21 e checksum (entram no CP-3E)"
  skip "WildFly 41 e checksum (entram no CP-3E)"
fi

if [[ "$CI_MODE" != true ]] && rank_at_least CP-3J; then
  check_java "OpenJDK 25" JAVA25_HOME 'version \"25' JAVA25_ARCHIVE JAVA25_ARCHIVE_SHA256
else
  skip "OpenJDK 25 e checksum (entram no CP-3J)"
fi

printf '\nResumo: %d OK, %d falha(s), %d aviso(s), %d não exigido(s).\n' \
  "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT" "$SKIP_COUNT"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
