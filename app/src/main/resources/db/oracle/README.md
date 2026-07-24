# Scripts Oracle 19c

Execute com um schema dedicado ao laboratório e com privilégios apenas para
criar tabela, sequence e índice nesse schema:

```text
@001_schema.sql
@002_seed.sql
```

Os dois scripts são idempotentes. A segunda execução não recria objetos nem
duplica o pedido semente. Antes de executar `rollback.sql`, confirme que o
schema é o do laboratório; o rollback remove permanentemente as duas tabelas e
as duas sequences criadas por estes scripts.

O usuário de aplicação não deve receber privilégio para executar DDL. Em um
ambiente equivalente a produção, um usuário de migração aplica os scripts e o
datasource usa outro usuário com somente DML e acesso às sequences necessárias.
