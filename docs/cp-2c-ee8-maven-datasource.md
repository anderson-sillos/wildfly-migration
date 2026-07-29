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

```bash
./scripts/validate-cp-2c.sh
./scripts/build-cp-2c.sh --profile ci-h2 --env .env
./scripts/validate-cp-2c.sh \
  --war app/target/wildfly-migration.war
```

O build deve continuar gerando bytecode Java 8. A auditoria compara
`WEB-INF/lib` com a allowlist da fase 2 e também inspeciona os JARs empacotados
para rejeitar classes de Servlet, JSP, JSTL ou EL fornecidas pelo contêiner.

Esta alteração não atualiza as bibliotecas legadas, não muda o contrato HTTP,
não altera o datasource e não comprova ainda a paridade H2/Oracle do CP-2C.

## 2.12 — Maven 3.9.16

O build ativo passa de Maven 3.8.9 para 3.9.16. A distribuição oficial está
fixada no manifesto da fase 2 com:

- origem:
  <https://downloads.apache.org/maven/maven-3/3.9.16/binaries/apache-maven-3.9.16-bin.tar.gz>;
- tamanho: `9278065` bytes;
- SHA-256:
  `80ffca22aed9e8b9713a232f3394fd81d7f20322df75efdb2b047dbd3e3a23bb`;
- SHA-512 publicado:
  `831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6`;
- licença: Apache License 2.0.

O wrapper `build-cp-2c.sh` seleciona explicitamente Java 8 e Maven 3.9.16.
O Enforcer do POM também exige exatamente `[3.9.16]`, impedindo um sucesso
acidental com outra instalação.

O `portable-ci` usa a mesma combinação: identifica o ambiente como `CP-2C`,
baixa a distribuição Maven registrada no manifesto, valida seu SHA-256,
executa `doctor.sh CP-2C --ci` e constrói o WAR por `build-cp-2c.sh`. O
validador estático exige que POM, manifesto, cache lock, chave de cache,
download, `MAVEN_HOME`, wrapper e workflow permaneçam em Maven 3.9.16. Assim,
uma divergência entre configuração local e CI falha em `repository-baseline`
antes da trilha portátil completa.

### Maven 3.9.16 não é `modelVersion` 4.0.0

São dois contratos independentes:

| Campo | Significado no laboratório |
| --- | --- |
| `Apache Maven 3.9.16` | versão da ferramenta que lê o POM e executa o build |
| `<modelVersion>4.0.0</modelVersion>` | versão do modelo do descritor de projeto; único valor suportado pelo Maven 3 |

Portanto, manter `modelVersion` em `4.0.0` não seleciona Maven 4. O Maven 4
continua fora deste gate.

Na passagem de 3.8.x para 3.9.x, as notas oficiais alertam principalmente
para o transporte HTTP nativo, dependências internas antes injetadas
implicitamente em plugins e validações adicionais de plugins. O `clean verify`
do laboratório é a prova de compatibilidade dos plugins realmente usados; uma
aprovação aqui não generaliza essa conclusão para todos os plugins de uma
aplicação real.

Referências oficiais:

- <https://maven.apache.org/install.html>;
- <https://maven.apache.org/ref/3.9.16/maven-model/maven.html>;
- <https://maven.apache.org/docs/3.9.16/release-notes.html>.
