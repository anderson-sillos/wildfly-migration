# Persistência MyBatis do baseline legado

O CP-1E preserva MyBatis 3.4.5 e usa o mesmo contrato
`java:/jdbc/MigrationDS` nos perfis `ci-h2` e `oracle`. URL, usuário, senha e
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

## Limites da validação

A validação estática comprova a estrutura dos mappers, aliases, handler, JNDI,
transações e isolamento do SQL específico. O smoke HTTP do checkpoint 1.24
comprovará o fluxo completo no WildFly/H2 e no WildFly/Oracle. Somente o
resultado Oracle pode qualificar comportamento do `ojdbc7`, timestamps, BLOBs e
rollback no Oracle 19c.
