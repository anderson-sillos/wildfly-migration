#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -ne 0 ]]; then
  printf 'Uso: ./scripts/validate-cp-1d-profiles.sh\n' >&2
  exit 2
fi

required_variables=(
  MIGRATION_DB_PROFILE
  JAVA7_PORTABLE_HOME
  JAVA7_PORTABLE_ARCHIVE
  JAVA7_PORTABLE_ARCHIVE_SHA256
  ORACLE_DB_URL
  ORACLE_DB_USER
  ORACLE_DB_PASSWORD
  OJDBC7_JAR
  OJDBC7_SHA256
  H2_JAR
  H2_SHA256
)

for variable in "${required_variables[@]}"; do
  if [[ "$(grep -Ec "^${variable}=" "$REPOSITORY_ROOT/.env.example")" != "1" ]]; then
    printf 'FALHA: .env.example deve declarar %s exatamente uma vez\n' \
      "$variable" >&2
    exit 1
  fi
done

redundant_placeholders=(
  "app/src/main/java/.gitkeep"
  "app/src/main/resources/.gitkeep"
  "app/src/main/webapp/WEB-INF/.gitkeep"
)

for path in "${redundant_placeholders[@]}"; do
  if [[ -e "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: placeholder redundante ainda existe: %s\n' "$path" >&2
    exit 1
  fi
done

for path in app/src/test/java/.gitkeep app/src/test/resources/.gitkeep; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: placeholder necessário para diretório vazio ausente: %s\n' \
      "$path" >&2
    exit 1
  fi
done

ignored_examples=(
  ".env.ci-h2"
  ".env.oracle"
  ".secrets/database-password"
  "oracle-wallet/ewallet.p12"
  "h2-1.4.200.jar"
  "ojdbc7.jar"
  "zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz"
)

for path in "${ignored_examples[@]}"; do
  if ! git -C "$REPOSITORY_ROOT" check-ignore -q "$path"; then
    printf 'FALHA: caminho sensível ou externo não está ignorado: %s\n' \
      "$path" >&2
    exit 1
  fi
done

if "$REPOSITORY_ROOT/scripts/doctor.sh" CP-1D \
    --profile perfil-invalido --ci >/dev/null 2>&1; then
  printf 'FALHA: doctor aceitou perfil de banco inválido\n' >&2
  exit 1
fi

if "$REPOSITORY_ROOT/scripts/doctor.sh" CP-1D \
    --profile oracle --ci >/dev/null 2>&1; then
  printf 'FALHA: doctor permitiu perfil Oracle no modo CI portátil\n' >&2
  exit 1
fi

if ! grep -Fq '[[ "$DB_PROFILE" == "ci-h2" ]]' \
    "$REPOSITORY_ROOT/scripts/doctor.sh" ||
   ! grep -Fq 'check_oracle_variables' \
    "$REPOSITORY_ROOT/scripts/doctor.sh" ||
   ! grep -Fq 'check_h2' "$REPOSITORY_ROOT/scripts/doctor.sh"; then
  printf 'FALHA: doctor não contém os gates separados H2/Oracle\n' >&2
  exit 1
fi

if ! grep -Eq 'jsp-api\|jstl-api\|h2' \
    "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh" ||
   ! grep -Eq 'ojdbc\[\^/\]' \
    "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh" ||
   ! grep -Fq 'configuração sensível foi empacotado' \
    "$REPOSITORY_ROOT/scripts/audit-legacy-war.sh"; then
  printf 'FALHA: auditoria do WAR não contém todos os bloqueios do CP-1D\n' >&2
  exit 1
fi

if git -C "$REPOSITORY_ROOT" ls-files '*.jar' | grep -q .; then
  printf 'FALHA: há driver JAR versionado\n' >&2
  exit 1
fi

printf 'OK: perfis ci-h2/oracle e guardas do CP-1D validados\n'
