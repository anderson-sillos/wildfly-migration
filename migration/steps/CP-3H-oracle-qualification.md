# CP-3H / atividade 3.38 — qualificação Oracle 19c

## Escopo

Esta atividade registra a execução do destino Java 21/WildFly 41 contra a
instância Oracle 19c autorizada. Ela complementa o smoke de provisionamento da
3.37 com a identidade observada do banco, do Release Update, do `ojdbc17`, da
JVM e do WildFly. URL, usuário, senha, wallet e endereço interno não são
copiados para a evidência.

## Execução

Em uma máquina com acesso à rede interna, schema descartável e `.env` fora do
controle de versão:

```bash
./scripts/qualify-cp-3h-oracle.sh \
  --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --non-interactive
```

O fluxo:

1. executa `doctor CP-3H` e valida o módulo externo e os checksums;
2. consulta `PRODUCT_COMPONENT_VERSION.VERSION_FULL` com `ojdbc17` e exige
   Oracle Database 19c `19.3.0.0.0`;
3. executa os 15 contratos HTTP pelo datasource Oracle do WildFly 41;
4. extrai do log sanitizado a versão observada do WildFly e grava a evidência.

O resultado fica em
`migration/evidence/CP-3H/oracle-qualification.json`. Dados transitórios
criados pelo smoke usam o prefixo `LAB-SMOKE-` e são removidos pelo próprio
script.

## Resultado esperado e rollback

A aprovação exige `ojdbc17-23.26.2.0.0`, Temurin 21.0.12+8, WildFly
41.0.0.Final, RU Oracle `19.3.0.0.0`, `java:/jdbc/MigrationDS` e 15/15
cenários. O rollback é somente de código/runtime para o commit integrado do
CP-3G; não remove o schema Oracle nem dados externos.
