# CP-3I/3.41 — Semântica de persistência no Java 21

## Objetivo

Validar, antes da suíte completa do gate Java 21, as diferenças que não podem
ser inferidas somente pelo H2: rollback transacional, avanço de sequences,
paginação ordenada, conversão JDBC de `TIMESTAMP(6)` em fusos diferentes,
round-trip de CLOB e BLOB e limpeza dos dados transitórios.

O probe usa JDBC diretamente para isolar a fronteira banco/driver. Ele não
altera o WAR, não cria tabelas e não executa `rollback.sql`. No H2, o banco é
novo e em memória; no Oracle, o schema descartável já preparado é usado e
somente registros com prefixo `LAB-CP3I-` são removidos.

## Execução

Com o WAR do gate Java 21 construído:

```bash
./scripts/qualify-cp-3i-persistence.sh \
  --profile ci-h2 --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --result migration/evidence/CP-3I/persistence-ci-h2.json

./scripts/qualify-cp-3i-persistence.sh \
  --profile oracle --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --result migration/evidence/CP-3I/persistence-oracle.json
```

O perfil Oracle deve ser executado somente em rede autorizada. O relatório
registra a versão do banco e do driver, mas nunca URL, usuário, senha ou
wallet.

## Semântica coberta

- `rollback`: inserção dentro de transação seguida de `ROLLBACK` não deixa
  registro persistido;
- `sequence`: duas chamadas consecutivas de `LAB_PEDIDO_SEQ` avançam em ordem;
- `pagination`: `ORDER BY ID OFFSET ... FETCH NEXT ...` retorna a página
  esperada em ambos os bancos;
- `timestampTimezone`: `TIMESTAMP(6)` é lido com calendários UTC e
  America/Sao_Paulo e `SYSTIMESTAMP`/`CURRENT_TIMESTAMP` retornam valores;
- `clob`: conteúdo Unicode é enviado e lido como `java.sql.Clob`;
- `blob`: bytes binários são enviados e lidos como `java.sql.Blob`;
- `cleanup`: registros de probe e o anexo associado são removidos com commit.

## Rollback

O rollback da atividade é abandonar o checkout/commit do CP-3I e retornar ao
CP-3H. O probe não modifica DDL, sequences são deliberadamente não
transacionais e somente os registros temporários com seu prefixo são limpos.
