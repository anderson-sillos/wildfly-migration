# INC-006 — WildFly 9 passa uma opção PermGen removida ao Java 8

## Identificação

- checkpoint: `CP-2A`;
- estado verde de origem: `migration/01-legacy-baseline`;
- runtime de destino: Eclipse Temurin 8u492-b09 no WildFly 9.0.2.Final;
- etapa: `execution`;
- categoria: configuração da JVM;
- reprodução: `natural`;
- perfis afetados: `portable-ci` e `oracle-qualified`.

## Tentativa antes da correção

O WAR congelado, ainda com bytecode Java 7 major `51`, foi iniciado sem
recompilação no WildFly 9 usando `JAVA_HOME` do Temurin 8. Os 14 contratos
passaram, mas a inicialização publicou um aviso estável.

## Assinatura sanitizada

```text
ignoring option MaxPermSize=256m; support was removed in 8.0
```

## Causa-raiz

O `standalone.conf` distribuído com WildFly 9 define
`-XX:MaxPermSize=256m`. O Java 8 removeu a geração permanente e ignora essa
opção. Não houve quebra funcional, mas conservar o parâmetro mascara a
diferença de runtime e gera ruído operacional.

## Menor correção

Ao selecionar Java 8, remover somente `-XX:MaxPermSize` da cópia temporária do
runtime. A instalação externa do WildFly e a reprodução da tag de baseline
permanecem inalteradas.

## Evidências antes e depois

- antes:
  [`before-runtime.properties`](../evidence/CP-2A/before-runtime.properties);
- depois: smoke do CP-2A exige inicialização sem a assinatura acima e executa
  os mesmos contratos.

## Aplicação equivalente no sistema real

Revise scripts de serviço, `standalone.conf`, imagens e variáveis `JAVA_OPTS`
antes de trocar a JVM. Remova apenas flags comprovadamente obsoletas; preserve
limites de heap e demais opções até que sejam avaliados separadamente.

## Teste de regressão

```bash
./scripts/smoke-wildfly9-datasource.sh \
  --java 8 --profile ci-h2 --env .env \
  --war app/target/wildfly-migration.war
```

## Rollback

Use a tag `migration/01-legacy-baseline`, cuja cópia do runtime continua
executando com Java 7 e conserva sua configuração histórica.
