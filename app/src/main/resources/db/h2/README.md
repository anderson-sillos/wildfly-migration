# Scripts H2 1.4.200

Estes scripts existem somente para `portable-ci` e devem ser executados na
ordem:

```text
001_schema.sql
002_seed.sql
```

Use uma URL em memória com `MODE=Oracle`, sem listener ou console:

```text
jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1
```

Schema e seed são idempotentes. `rollback.sql` remove somente as duas tabelas e
as duas sequences do laboratório. O H2 não é a fonte canônica do DDL: qualquer
alteração começa nos scripts Oracle e precisa ser refletida aqui com a
divergência documentada.

Não reutilize estes scripts contra Oracle e não simplifique os scripts Oracle
para compartilhá-los. As diferenças e os limites de qualificação estão em
[`h2-oracle-differences.md`](../../../../../../docs/h2-oracle-differences.md).
