# Perfis de datasource do WildFly 9

Os dois perfis publicam o mesmo contrato:

```text
pool-name: MigrationDS
jndi-name: java:/jdbc/MigrationDS
```

`ci-h2.cli` usa H2 1.4.200 em memória e não declara usuário, senha, console ou
listener. `oracle.cli` usa `ojdbc7` e mantém URL, usuário e senha como
expressões `${env.ORACLE_DB_*}` resolvidas pelo processo do WildFly. Nenhum
valor real é gravado no XML ou nos arquivos CLI.

Os arquivos são aplicados somente sobre uma cópia temporária e limpa do
WildFly pelo script:

```bash
./scripts/validate-cp-1d-datasources.sh
./scripts/smoke-wildfly9-datasource.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh --profile oracle --env .env
```

O smoke liga HTTP e management apenas em `127.0.0.1`, executa
`test-connection-in-pool`, registra somente resultado sanitizado e encerra o
servidor. O perfil Oracle deve ser executado apenas em máquina autorizada na
rede interna.

O workflow hospedado baixa e verifica Zulu Java 7, Maven 3.8.9, WildFly
9.0.2.Final e H2 1.4.200 em uma pasta efêmera do runner. Ele não recebe
`ojdbc7`, URL ou credenciais Oracle e, portanto, registra somente o estado
`portable-ci`. O estado `oracle-qualified` é produzido separadamente, com o
mesmo script de smoke, na rede interna.
