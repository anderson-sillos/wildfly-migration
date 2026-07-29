# Aplicação evolutiva

Esta é a única árvore de código da aplicação do laboratório. Ela começa no
baseline legado e será alterada, na mesma linha Git, até o destino Jakarta EE
11. Estados anteriores serão preservados por commits e pelas três tags públicas,
não por cópias da aplicação em outros diretórios.

## Estrutura inicial

| Caminho | Responsabilidade |
| --- | --- |
| `src/main/java/` | código Java da aplicação |
| `src/main/resources/` | recursos empacotados e configurações da aplicação |
| `src/main/webapp/` | JSPs, conteúdo web e descritores |
| `src/main/webapp/WEB-INF/` | conteúdo protegido e descritores do WAR |
| `src/test/java/` | testes internos da aplicação |
| `src/test/resources/` | recursos dos testes internos |

O CP-1C adicionou o `pom.xml` e o descritor Servlet 2.4. O CP-1D estabeleceu os
perfis de datasource e o CP-1E iniciou o domínio e os mappers. A tag
`migration/01-legacy-baseline` preserva esse estado Java 7.

Build do estado atual, durante o CP-2C:

```bash
./scripts/build-cp-2c.sh --profile ci-h2 --env .env
```

O wrapper exige Maven 3.9.16 executando no Temurin OpenJDK 8u492-b09, compila
bytecode major `52` e audita o WAR. O build usa o Jakarta EE Web Profile 8 em
`provided`, cujas APIs ainda permanecem em pacotes `javax.*`. Para reproduzir
o build Java 7 ou os estados intermediários com Maven 3.8.9, materialize a tag
ou o commit do checkpoint correspondente e siga o runbook congelado.

Nenhum JAR manual, driver Oracle, runtime ou arquivo gerado em `target/` deve
ser versionado.

A configuração, o limite transacional e a pequena divergência de sequences
entre os bancos estão em
[`docs/mybatis-persistence.md`](../docs/mybatis-persistence.md).
