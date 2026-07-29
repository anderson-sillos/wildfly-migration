# Evidência CP-2C — EE 8, Maven 3.9.16 e persistência

## Escopo

- estado verde de origem: CP-2B, commit
  `3c0b80373370494ccccd15ec07be4dae8d51a155`;
- revisão qualificada:
  `abad422e4d446aff40a7c3fae306083f535139a5`;
- runtime: Eclipse Temurin OpenJDK 8u492-b09 e WildFly comunitário
  26.1.3.Final;
- build: Maven 3.9.16 e Jakarta EE Web Profile 8.0 em `provided`;
- namespace preservado: `javax.*`;
- banco oficial: Oracle Database 19c RU 19.3 com
  `ojdbc7` 12.1.0.2.0 fornecido externamente.

## Resultados preservados

| Verificação | H2 `portable-ci` | Oracle `oracle-qualified` |
| --- | --- | --- |
| `doctor` Java 8/WildFly 26/Maven 3.9.16 | aprovado | 136 itens aprovados |
| Build e auditoria do WAR | aprovado | aprovado |
| Pool `java:/jdbc/MigrationDS` | aprovado | aprovado |
| Contratos HTTP | 14/14 | 14/14 |
| Estado persistido via MyBatis | aprovado | aprovado |
| Commit MyBatis | portátil | aprovado no Oracle |
| Rollback depois de falha intencional | não qualifica Oracle | aprovado |
| `TIMESTAMP(6)` em nova consulta | não qualifica Oracle | aprovado |
| BLOB byte a byte em nova consulta | não qualifica Oracle | aprovado |
| Limpeza dos dados transitórios | aprovado | aprovado |

As duas trilhas usaram a mesma revisão de origem e, nesta execução, produziram
o mesmo WAR:

```text
sourceCommit=abad422e4d446aff40a7c3fae306083f535139a5
warSha256=62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2
```

O relatório H2 registra também
`364947055e2f3cc191f4925980e78c3cc6395b68`, que é o commit de merge
sintético efetivamente executado pelo GitHub Actions. Essa separação evita
apresentar o HEAD da branch como se ele fosse o commit testado pelo runner.

Os registros legíveis por máquina estão em:

- [`contract-ci-h2.json`](../../migration/evidence/CP-2C/contract-ci-h2.json);
- [`contract-oracle.json`](../../migration/evidence/CP-2C/contract-oracle.json);
- [`oracle-persistence.json`](../../migration/evidence/CP-2C/oracle-persistence.json);
- [`after.properties`](../../migration/evidence/CP-2C/after.properties).

Nenhum deles contém URL JDBC, host interno, usuário, senha ou wallet.

## CI hospedado

O PR
[#17](https://github.com/anderson-sillos/wildfly-migration/pull/17)
executou a revisão no GitHub Actions sem acesso à rede Oracle. A execução
[`30494074305`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30494074305)
concluiu o `portable-ci` em 50 segundos. Ela restaurou os caches reutilizáveis,
revalidou os quatro arquivos de runtime por SHA-256, construiu e auditou o
WAR, compilou a sonda Oracle sem driver ou credenciais, publicou o datasource
H2 em memória e aprovou os 14 contratos.

A execução
[`30494074318`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30494074318)
aprovou `repository-baseline`. O relatório H2 foi baixado do artefato
`cp-2c-portable-contract-result`; ele não foi reconstruído manualmente.

## Qualificação Oracle

Na rede interna, `./scripts/qualify-cp-2c-oracle.sh --env .env`:

1. aprovou 131 verificações do `doctor`;
2. verificou o schema descartável `LAB_*`;
3. reconstruiu e auditou o WAR com Java 8/Maven 3.9.16;
4. provisionou o `ojdbc7` e o pool do WildFly 26;
5. aprovou os mesmos 14 contratos HTTP;
6. carregou do WAR atual as classes e mappers MyBatis;
7. comprovou commit, rollback intencional, `TIMESTAMP(6)` e BLOB no Oracle;
8. removeu somente os registros transitórios identificados pelo laboratório.

O banco retornou `19.3.0.0.0` e o driver efetivo retornou `12.1.0.2.0`.
O relatório registra apenas esses metadados não sensíveis.

## Conclusão comprovada

### Alinhamento EE 8 sem migração prematura para `jakarta.*`

O CP-2C comprova que a aplicação pode substituir as APIs históricas separadas
de Servlet, JSP e JSTL pela API agregada
`jakarta.platform:jakarta.jakartaee-web-api:8.0.0`, ainda usando os pacotes
binários `javax.*`. A dependência permanece em `provided`; a auditoria
encontrou zero JAR de API do contêiner e 20 bibliotecas da aplicação em
`WEB-INF/lib`.

Essa mudança alinha o contrato de compilação ao WildFly 26 sem antecipar a
quebra de namespace reservada ao gate Jakarta da fase 3.

### Maven atualizado sem alterar o modelo do projeto

Maven 3.9.16 executou o build com Java 8 e substituiu Maven 3.8.9 como
ferramenta ativa a partir deste checkpoint. O
`<modelVersion>4.0.0</modelVersion>` permaneceu correto: ele identifica o
modelo do POM e não a versão instalada do Maven.

### Paridade funcional e qualificação de persistência

Os mesmos 14 cenários de saúde, pedidos, sessão, upload, XML e estado
persistido passaram em H2 e Oracle. Isso preserva o contrato funcional da
aplicação depois das mudanças de API e de ferramenta de build.

O resultado H2 comprova somente a semântica portátil e o caminho
JNDI/MyBatis. A sonda separada no Oracle 19c comprovou o driver aprovado,
commit, rollback depois de uma falha real dentro da transação, precisão de
milissegundos em colunas `TIMESTAMP(6)` e conteúdo BLOB byte a byte recuperado
em nova consulta.

### Empacotamento e segredos preservados

H2 e `ojdbc7` continuaram fora do WAR. URL, usuário e senha permaneceram no
`.env` ignorado e não aparecem nos relatórios. O WildFly controla driver,
pool e `java:/jdbc/MigrationDS`; o código de negócio não escolhe o fornecedor.

### Limites da conclusão

O CP-2C não transforma H2 em prova Oracle e não qualifica procedures, tipos
Oracle proprietários, timezone, paginação ou carga que a aplicação do
laboratório ainda não utiliza. Java 8, WildFly 26 e `ojdbc7` continuam sendo
uma ponte EOL, não o destino final.

Também não atualiza as bibliotecas legadas: MyBatis 3.4.5, Log4j 1, Tiles,
Commons FileUpload, Reflections, XMLBeans e dom4j permanecem deliberadamente
para que suas mudanças sejam isoladas nos gates seguintes.

## Rollback

O retorno seguro é o commit do CP-2B
`3c0b80373370494ccccd15ec07be4dae8d51a155`. Ele restaura Maven 3.8.9 e as
declarações de API anteriores, mantendo Java 8/WildFly 26 e seus perfis.

O runtime é sempre criado como cópia temporária; descartá-la não altera a
distribuição externa. O rollback do código não exige downgrade de schema nem
restauração de dados, porque o CP-2C não modificou DDL ou dados permanentes.
Antes de retornar, execute a limpeza documentada dos registros
`LAB-SMOKE-*`.
