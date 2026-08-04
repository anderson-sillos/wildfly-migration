# Persistência MyBatis

## Evolução da versão

O baseline e a fase 2 preservam MyBatis 3.4.5. A atividade 3.6 atualiza a
aplicação ativa para MyBatis 3.5.19 no gate Java 17/WildFly 26, mantendo o
mesmo contrato `java:/jdbc/MigrationDS`, os mesmos mappers XML e o namespace
EE 8 `javax.*`.

As allowlists históricas continuam registrando MyBatis 3.4.5. Somente a
allowlist do gate Java 17 aceita `mybatis-3.5.19.jar`. URL, usuário, senha e
drivers continuam exclusivamente na configuração externa do WildFly; não há
fallback JDBC dentro do WAR.

## Limite transacional

Os dois perfis provisionam um datasource local não-JTA (`jta=false`). O
`MyBatisTransactionTemplate` abre a `SqlSession` com `autoCommit=false`,
confirma a unidade de trabalho somente depois de sua conclusão, executa
rollback diante de `RuntimeException` ou `Error` e sempre fecha a sessão.

Essa decisão corresponde à forma de transação usada pelo MyBatis sem Spring ou
EJB e evita um limite híbrido no qual o MyBatis tenta confirmar uma conexão já
controlada por JTA. A aplicação não deve chamar os mappers fora do template.
Se a aplicação real usar transações distribuídas, EJB ou `UserTransaction`,
esse é um ponto de adaptação explícito, não algo que o laboratório presume.

## Recursos compartilhados

- `mybatis-config.xml` declara os aliases `pedido` e `anexo`, os handlers de
  `StatusPedido` e SHA-256, o datasource JNDI e os dois mappers;
- `PedidoMapper.xml` contém listagem, consulta, inclusão e atualização;
- `AnexoMapper.xml` contém consulta, inclusão e leitura do BLOB;
- `StatusPedidoTypeHandler` mantém o enum textual igual nos dois bancos;
- `Sha256TypeHandler` remove somente o preenchimento de `CHAR` e rejeita
  digests fora do contrato hexadecimal minúsculo de 64 posições;
- `PedidoRepository` demonstra validação mínima e criação atômica do pedido.

Todos os `SELECT`, `INSERT` e `UPDATE` funcionais são únicos. Apenas
`proximoId` tem duas declarações selecionadas por `databaseIdProvider`, pois o
Oracle usa `LAB_*_SEQ.NEXTVAL FROM DUAL` e o adaptador H2 usa
`NEXT VALUE FOR LAB_*_SEQ`.

O identificador de fornecedor vem do `DatabaseMetaData`: `Oracle` seleciona
`oracle` e `H2` seleciona `h2`. Um banco não reconhecido falha ao tentar obter
o próximo ID em vez de executar uma variante presumida.

## Validação da atualização

A sonda da atividade 3.6 executa separadamente em H2 e Oracle:

- carregamento dos mappers `PedidoMapper` e `AnexoMapper`;
- resolução dos aliases `pedido` e `anexo`;
- seleção dos type handlers de `StatusPedido` e SHA-256;
- leitura e escrita por reflexão da propriedade `Pedido.numero` pelas APIs
  `MetaClass` e `MetaObject` do MyBatis;
- commit por uma nova sessão e rollback de uma falha intencional;
- round-trip de timestamps e BLOB no Oracle.

Os contratos HTTP completos são repetidos para detectar regressões fora da
sonda de persistência. O relatório H2 é classificado como `portable-ci`; apenas
o relatório executado no Oracle 19c recebe `oracle-qualified`.

## Logging

MyBatis 3.5.19 usa explicitamente `logImpl=SLF4J` no destino Jakarta. A
autodetecção deixa de participar da seleção, evitando que a ordem dos módulos
do servidor altere o comportamento. A API SLF4J é fornecida pelo WildFly 41 e
o WAR não empacota ponte, API duplicada ou backend concorrente.

## Limites da validação

A validação estática comprova a estrutura dos mappers, aliases, handler, JNDI,
transações e isolamento do SQL específico. Os smokes do checkpoint ativo
comprovam o fluxo completo no WildFly/H2 e no WildFly/Oracle. Somente o
resultado Oracle pode qualificar comportamento do `ojdbc7`, timestamps, BLOBs
e rollback no Oracle 19c.
