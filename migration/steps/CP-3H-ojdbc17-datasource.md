# CP-3H / atividade 3.37 — datasource Oracle e H2

## Decisão

O destino Java 21/WildFly 41 mantém um único contrato de persistência:
`java:/jdbc/MigrationDS`. O WildFly cria e valida o pool; a aplicação continua
usando somente JNDI e MyBatis. O driver escolhido para Oracle 19c é
`com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` e fica em um módulo do servidor,
fora do WAR. O H2 permanece exclusivamente como infraestrutura portátil de
teste em memória.

Origem, licença e checksum do JAR estão em
[`runtime-manifest.tsv`](../../runtime/phase3/java21-wildfly41/runtime-manifest.tsv).
O JAR Oracle não é versionado nem incluído no cache portátil; deve ser
fornecido externamente por `OJDBC17_JAR` e conferido por `OJDBC17_SHA256`.

## Perfis

| Perfil | Módulo do servidor | Conexão | Pool | Classificação |
| --- | --- | --- | --- | --- |
| `ci-h2` | `com.h2database.h2` (slot `cp3f`) | H2 em memória, modo Oracle | 1–5, validação `SELECT 1` | `portable-ci` |
| `oracle` | `com.oracle.ojdbc17` | `${env.ORACLE_DB_URL}` | 1–10, validação `SELECT 1 FROM DUAL` | `oracle-qualified` |

Ambos usam `java:/jdbc/MigrationDS`; nenhum perfil altera o código de negócio.
O perfil Oracle exige uma instância Oracle 19c acessível apenas a partir de
uma rede autorizada e um schema descartável.

## Execução H2 portátil

Depois de preparar Java 21, WildFly 41, H2 e um WAR Jakarta:

```bash
./scripts/smoke-wildfly41-datasource.sh \
  --profile ci-h2 --env /dev/null \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --result app/target/contract-results/cp3h-h2-contract.json \
  --diagnostic-log app/target/contract-results/cp3h-h2-server.log
```

O comando cria o módulo H2 somente na cópia temporária do WildFly, aplica
`profiles/ci-h2.cli`, executa a suíte HTTP e remove a instância ao terminar.
Não exige credenciais Oracle.

## Execução Oracle autorizada

Com `.env` preenchido fora do Git e o schema de laboratório preparado:

```bash
./scripts/validate-cp-3h-datasource.sh --env .env --verify-external
./scripts/smoke-wildfly41-datasource.sh \
  --profile oracle --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --result app/target/contract-results/cp3h-oracle-contract.json \
  --diagnostic-log app/target/contract-results/cp3h-oracle-server.log
```

O script copia o WildFly para um diretório temporário, instala o JAR externo
em `modules/com/oracle/ojdbc17/main/ojdbc17.jar`, aplica `profiles/oracle.cli`,
executa a mesma suíte HTTP e sanitiza o log. A senha, URL completa, usuário e
wallet nunca entram no relatório.

O registro da versão completa do Oracle, Release Update, JVM, driver e WildFly
é uma atividade separada (3.38); esta atividade comprova a seleção do módulo,
o datasource e o smoke funcional do perfil.

## Verificação e rollback

```bash
./scripts/validate-cp-3h-datasource.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war
```

O validador confirma os dois perfis, o manifesto, o módulo, o JNDI, a ausência
de drivers no WAR e a ausência do OJDBC no cache portátil. Para retornar ao
estado anterior, descarte somente a alteração do módulo/perfil e volte ao
commit integrado do CP-3G; nenhuma operação de DDL ou limpeza de dados Oracle
faz parte do rollback.
