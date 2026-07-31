# INC-013 — Constraint H2 2.4 falha após troca de conexão

## Identificação

- checkpoint: `CP-3A`;
- origem: H2 1.4.200 em memória;
- alvo: H2 2.4.240 em memória;
- etapa: execução da persistência;
- categoria: SQL portátil do harness;
- reprodução: natural;
- perfil afetado: somente `portable-ci`.

## Tentativa antes da correção

O schema foi criado em uma conexão, que foi fechada normalmente. Ao executar a
massa idempotente pela conexão seguinte, o H2 2.4.240 rejeitou o valor
`STATUS='NOVO'`, embora ele estivesse listado na constraint
`CHECK (STATUS IN (...))`.

## Assinatura sanitizada

```text
JdbcSQLIntegrityConstraintViolationException:
Check constraint invalid: CK_LAB_PEDIDO_STATUS
Caused by: JdbcSQLNonTransientConnectionException:
The database has been closed [90098-240]
```

## Causa observada

A expressão `IN` da constraint criada pelo H2 2.4.240 manteve estado associado
à sessão que compilou a expressão. Depois que essa conexão foi fechada, a
avaliação feita pela conexão seguinte alcançou uma sessão encerrada. O mesmo
DDL e o mesmo valor passavam no H2 1.4.200.

Essa é uma incompatibilidade do adaptador H2; o Oracle 19c canônico continua
usando sua constraint original e não é alterado.

## Menor correção

No script exclusivo do H2, expressar o mesmo conjunto fechado como `CASE`. Uma
primeira tentativa com comparações ligadas por `OR` foi normalizada novamente
para `IN` pelo otimizador e reproduziu a falha:

```sql
CHECK (
  CASE STATUS
    WHEN 'NOVO' THEN TRUE
    WHEN 'APROVADO' THEN TRUE
    WHEN 'CANCELADO' THEN TRUE
    ELSE FALSE
  END
)
```

A regra funcional permanece idêntica e não exige mudança em Java, mapper,
schema Oracle ou WAR.

## Teste de regressão

```bash
./scripts/validate-cp-1d-h2.sh \
  --java-home /opt/migration-lab/tools/jdk-17.0.20+8 \
  --h2-jar /opt/migration-lab/archives/h2-2.4.240.jar

./scripts/validate-cp-1e-persistence.sh \
  --java-home /opt/migration-lab/tools/jdk-17.0.20+8 \
  --h2-jar /opt/migration-lab/archives/h2-2.4.240.jar \
  --war app/target/wildfly-migration.war
```

O primeiro comando executa schema e massa duas vezes e limpa duas vezes. O
segundo abre conexões independentes e valida consultas, inserts, LOB e rollback
por MyBatis.

## Aplicação equivalente no sistema real

Ao atualizar H2 em uma suíte portátil, execute DDL e operações reais por mais
de uma conexão. Não trate aprovação no H2 como evidência de comportamento da
constraint ou de códigos de erro do Oracle.

## Rollback

Reverter somente o script H2 restaura a expressão `IN`. O schema Oracle e os
dados externos não participam desse rollback.
