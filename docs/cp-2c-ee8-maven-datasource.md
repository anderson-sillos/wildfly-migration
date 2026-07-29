# CP-2C — EE 8, Maven e datasource

Este checkpoint alinha o build e as verificações ao estado final da fase 2:
Java 8, WildFly 26.1.3, Jakarta EE 8 com pacotes `javax.*`, Maven 3.9.16 e o
mesmo datasource `java:/jdbc/MigrationDS`.

## 2.11 — APIs Jakarta EE 8

O POM ativo substitui as dependências históricas separadas de Servlet 2.4,
JSP 2.0 e JSTL 1.2 por:

```text
jakarta.platform:jakarta.jakartaee-web-api:8.0.0 (provided)
```

Essa é a coordenada oficial do Jakarta EE Web Profile 8. A versão 8 preserva
os pacotes `javax.*`; portanto, os imports da aplicação não mudam neste
checkpoint. A troca para pacotes `jakarta.*` permanece isolada no gate
WildFly 41/Jakarta EE 11 da fase 3.

O Web Profile 8 fornece ao build, entre outras APIs, Servlet 4.0, Server Pages
2.3, Expression Language 3.0 e Standard Tag Library 1.2. Como o WildFly 26
fornece essas APIs em execução, a dependência usa `provided`.

Referências oficiais:

- <https://jakarta.ee/specifications/webprofile/8/>;
- <https://jakarta.ee/specifications/webprofile/8/webprofile-spec-8>;
- <https://jakarta.ee/specifications/webprofile/8/apidocs/overview-summary>.

### Verificação

Durante a tarefa 2.11, Maven continua na versão 3.8.9 para que a atualização
da API não seja misturada com a troca da ferramenta de build prevista na
tarefa 2.12.

```bash
./scripts/validate-cp-2c.sh
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
./scripts/validate-cp-2c.sh \
  --war app/target/wildfly-migration.war
```

O build deve continuar gerando bytecode Java 8. A auditoria compara
`WEB-INF/lib` com a allowlist da fase 2 e também inspeciona os JARs empacotados
para rejeitar classes de Servlet, JSP, JSTL ou EL fornecidas pelo contêiner.

Esta alteração não atualiza as bibliotecas legadas, não muda o contrato HTTP,
não altera o datasource e não comprova ainda a paridade H2/Oracle do CP-2C.
