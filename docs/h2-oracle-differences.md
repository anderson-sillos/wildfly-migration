# Diferenças H2/Oracle do contrato de persistência

O Oracle 19c é a fonte canônica do schema. O H2 1.4.200 reproduz somente a
semântica portátil necessária ao feedback de pull requests. Aprovação H2 recebe
`portable-ci`; os itens marcados abaixo continuam pendentes até a execução
`oracle-qualified`.

A matriz cobre explicitamente tipos, constraints, sequences, timestamps e
LOBs, além dos mecanismos de idempotência e limpeza.

| Área | Oracle 19c canônico | H2 1.4.200 em `MODE=Oracle` | Limite da evidência portátil |
| --- | --- | --- | --- |
| inteiros de 64 bits | `NUMBER(19,0)` | `DECIMAL(19,0)` | precisão e escala são verificadas; conversão e códigos de erro do driver Oracle não |
| valores monetários | `NUMBER(15,2)` | `DECIMAL(15,2)` | sinal, precisão e escala são portáveis; arredondamento do driver precisa do Oracle |
| texto | `VARCHAR2(n CHAR)` | `VARCHAR(n)` | tamanho lógico e obrigatoriedade são equivalentes para os fixtures; semântica completa de caracteres e NLS não |
| digest | `CHAR(64 CHAR)` com `REGEXP_LIKE(..., ..., 'c')` | `CHAR(64)` com `REGEXP_LIKE(...)` | aceita somente hexadecimal minúsculo; collation e flags Oracle não são qualificadas |
| constraints | PK, UK, FK e CHECK nomeadas | mesmos nomes e regras | ordem/tempo de validação e códigos de violação podem divergir |
| sequences | `LAB_*_SEQ.NEXTVAL`, `NOCACHE NOCYCLE` | `NEXT VALUE FOR LAB_*_SEQ` | somente `proximoId` é duplicado por `databaseIdProvider`; geração, cache, concorrência e comportamento Oracle exigem qualificação |
| timestamps | `TIMESTAMP(6)` preenchido por `SYSTIMESTAMP` | `TIMESTAMP(6)` preenchido por `SYSTIMESTAMP` | H2 permite o fluxo e microssegundos; timezone, sessão, conversão JDBC e precisão efetiva precisam do Oracle |
| LOB binário | `BLOB` Oracle, normalmente por locator/stream | `BLOB` em memória | conteúdo e tamanho pequenos são portáveis; locator, streaming, limites e transação são Oracle-only |
| idempotência do DDL | blocos PL/SQL consultam `USER_*` | `CREATE ... IF NOT EXISTS` | ambos preservam objetos existentes, por mecanismos diferentes |
| idempotência da massa | `MERGE ... WHEN NOT MATCHED` | `INSERT ... SELECT ... WHERE NOT EXISTS` | ambos mantêm um único `LAB-0001`; plano, locks e concorrência não são equivalentes |
| limpeza | PL/SQL verifica objetos e usa `PURGE` | `DROP ... IF EXISTS` | remove os mesmos quatro objetos; recycle bin e commits implícitos não são simulados |
| string vazia | Oracle trata string vazia como `NULL` | fornecida pelo modo Oracle do H2 | somente os fixtures do laboratório são cobertos |

## Invariantes automatizados

O validador do CP-1D exige:

- tabelas `LAB_PEDIDO` e `LAB_ANEXO`;
- sequences `LAB_PEDIDO_SEQ` e `LAB_ANEXO_SEQ`;
- índice `IX_LAB_ANEXO_PEDIDO`;
- todos os nomes de PK, UK, FK e CHECK do Oracle;
- precisão e escala das colunas numéricas;
- `TIMESTAMP(6)`, `BLOB` e o CHECK do SHA-256;
- seed idempotente com exatamente um pedido `LAB-0001`;
- limpeza idempotente sem objetos remanescentes.

O mesmo validador proíbe PL/SQL, `USER_*`, `VARCHAR2` e `NUMBER(...)` nos
scripts H2 para impedir que o adaptador de teste se torne uma cópia ambígua do
DDL Oracle.

## Regras para mudanças futuras

1. Altere e revise primeiro `db/oracle`.
2. Classifique a mudança como SQL comum ou divergência de fornecedor.
3. Atualize `db/h2` sem enfraquecer constraints ou reduzir cobertura.
4. Atualize esta matriz.
5. Execute o validador H2 e, antes de qualificar o checkpoint, a suíte Oracle na
   rede interna.

H2 nunca decide qual comportamento prevalece quando os bancos divergem.
