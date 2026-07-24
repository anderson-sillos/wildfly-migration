#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H2_PROFILE="$REPOSITORY_ROOT/runtime/legacy/profiles/ci-h2.cli"
ORACLE_PROFILE="$REPOSITORY_ROOT/runtime/legacy/profiles/oracle.cli"
H2_MODULE="$REPOSITORY_ROOT/runtime/legacy/h2/module.xml"
ORACLE_MODULE="$REPOSITORY_ROOT/runtime/legacy/ojdbc7/module.xml.template"
CONTRACT="$REPOSITORY_ROOT/runtime/legacy/datasource-contract.properties"

if [[ $# -ne 0 ]]; then
  printf 'Uso: ./scripts/validate-cp-1d-datasources.sh\n' >&2
  exit 2
fi

required_paths=(
  "$H2_PROFILE"
  "$ORACLE_PROFILE"
  "$H2_MODULE"
  "$ORACLE_MODULE"
  "$CONTRACT"
  "$REPOSITORY_ROOT/runtime/legacy/profiles/README.md"
  "$REPOSITORY_ROOT/scripts/build-cp-1d.sh"
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$path" ]]; then
    printf 'FALHA: arquivo obrigatório ausente: %s\n' \
      "${path#"$REPOSITORY_ROOT/"}" >&2
    exit 1
  fi
done

for profile in "$H2_PROFILE" "$ORACLE_PROFILE"; do
  if [[ "$(grep -Fc 'jndi-name=java:/jdbc/MigrationDS' "$profile")" != "1" ||
        "$(grep -Fc 'pool-name=MigrationDS' "$profile")" != "1" ]]; then
    printf 'FALHA: perfil não publica exatamente o contrato MigrationDS: %s\n' \
      "${profile##*/}" >&2
    exit 1
  fi
done

if ! grep -Fq \
    'connection-url="jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1"' \
    "$H2_PROFILE" ||
   ! grep -Fq 'driver-module-name=com.h2database.h2.cp1d' "$H2_PROFILE" ||
   grep -Eiq \
    'jdbc:h2:(tcp|ssl)|AUTO_SERVER|createTcpServer|createWebServer|user-name=|password=' \
    "$H2_PROFILE"; then
  printf 'FALHA: perfil H2 não está restrito ao processo e sem credenciais\n' >&2
  exit 1
fi

for expression in \
  'connection-url="${env.ORACLE_DB_URL}"' \
  'user-name="${env.ORACLE_DB_USER}"' \
  'password="${env.ORACLE_DB_PASSWORD}"'; do
  if [[ "$(grep -Fc "$expression" "$ORACLE_PROFILE")" != "1" ]]; then
    printf 'FALHA: perfil Oracle não preserva a expressão externa %s\n' \
      "$expression" >&2
    exit 1
  fi
done

if ! grep -Fq 'driver-module-name=com.oracle.ojdbc7' "$ORACLE_PROFILE" ||
   ! grep -Fq \
    'valid-connection-checker-class-name=org.jboss.jca.adapters.jdbc.extensions.oracle.OracleValidConnectionChecker' \
    "$ORACLE_PROFILE" ||
   ! grep -Fq \
    'exception-sorter-class-name=org.jboss.jca.adapters.jdbc.extensions.oracle.OracleExceptionSorter' \
    "$ORACLE_PROFILE"; then
  printf 'FALHA: perfil Oracle não contém driver e validação aprovados\n' >&2
  exit 1
fi

if grep -Eiq \
    '(jdbc:oracle:thin:@|password="[^$]|password=[^"$]|localhost:1521|[[:digit:]]{1,3}(\\.[[:digit:]]{1,3}){3})' \
    "$ORACLE_PROFILE"; then
  printf 'FALHA: perfil Oracle contém endpoint ou credencial materializada\n' >&2
  exit 1
fi

if ! grep -Fq 'name="com.h2database.h2.cp1d"' "$H2_MODULE" ||
   ! grep -Fq 'path="h2-1.4.200.jar"' "$H2_MODULE" ||
   ! grep -Fq 'name="com.oracle.ojdbc7"' "$ORACLE_MODULE" ||
   ! grep -Fq 'path="ojdbc7.jar"' "$ORACLE_MODULE"; then
  printf 'FALHA: módulos externos de banco divergem do contrato\n' >&2
  exit 1
fi

contract_rules=(
  'datasource.jndi-name=java:/jdbc/MigrationDS'
  'datasource.pool-name=MigrationDS'
  'profile.ci-h2.driver.name=h2-cp1d'
  'profile.ci-h2.driver.module=com.h2database.h2.cp1d'
  'profile.oracle.driver.name=oracle'
  'profile.oracle.driver.module=com.oracle.ojdbc7'
)
for rule in "${contract_rules[@]}"; do
  if [[ "$(grep -Fxc "$rule" "$CONTRACT")" != "1" ]]; then
    printf 'FALHA: contrato de datasource ausente ou duplicado: %s\n' \
      "$rule" >&2
    exit 1
  fi
done

if ! grep -Fq -- '-b 127.0.0.1' \
    "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
   ! grep -Fq -- '-bmanagement 127.0.0.1' \
    "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" ||
   ! grep -Fq 'test-connection-in-pool' \
    "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh"; then
  printf 'FALHA: smoke não fixa loopback ou não testa o pool\n' >&2
  exit 1
fi

printf 'OK: perfis H2/Oracle, módulos e contrato JNDI validados estaticamente\n'
