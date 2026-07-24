# Evidência CP-1C — WAR e dependências legadas

## Escopo

- branch de entrega: `checkpoint/cp-1c-legacy-war`;
- commit squash esperado:
  `checkpoint(CP-1C): build legacy war skeleton`;
- única árvore da aplicação: `app/`;
- Java 7u80 e Maven 3.8.9 efetivamente usados no build;
- WAR estrutural, sem antecipar Servlets, JSPs, Tiles, persistência, upload ou
  importação XML dos checkpoints seguintes.

## Modelo Maven

O POM usa `modelVersion` 4.0.0, `packaging` WAR, source/target 1.7 e plugins
compatíveis com a JVM legada:

| Plugin | Versão |
| --- | --- |
| Maven Enforcer | `3.0.0-M3` |
| Maven Compiler | `3.8.1` |
| Maven WAR | `3.3.2` |
| Maven Dependency | `3.1.2` |

O Enforcer exige Maven `[3.8.9]` e Java 7u80 normalizado como
`[1.7.0-80]`. A URL canônica do
schema Maven no cabeçalho foi validada também pelo `effective-pom`, evitando
erro de catálogo XML no editor.

## Falhas reproduzidas antes da correção

1. Sem opção adicional, o Java 7 não resolveu os plugins no Maven Central.
2. Com TLS 1.2 explícito, surgiu `PKIX path building failed`, comprovando a
   cadeia desatualizada do truststore de 2015.
3. Depois de corrigir HTTPS, Enforcer `3.0.0` falhou com
   `Unsupported major.minor version 52.0`.

A correção mantém HTTPS validado: TLS 1.2 explícito, truststore JKS atualizado
do sistema e Enforcer `3.0.0-M3`, documentado como compatível com Java 7. O
registro completo está em
`migration/steps/CP-1C-legacy-build-https.md`.

## Dependências e empacotamento

As três APIs Servlet/JSP/JSTL têm escopo `provided`. As nove bibliotecas
informadas para o legado têm escopo `compile`. A árvore transitiva resultou em
14 arquivos sob `WEB-INF/lib`, fixados por nome em
`runtime/legacy/war-libraries.txt`.

A auditoria comprovou:

- nenhum JAR versionado ou manual fora de `app/target`;
- Servlet API, JSP API, JSTL API e `ojdbc7` ausentes do WAR;
- `LegacyBuildMarker.class` em major version 51;
- `WEB-INF/web.xml` presente e declarado como Servlet 2.4;
- WAR reproduzido duas vezes com SHA-256
  `29c25ad74c0eb466bddc5be4c3048dd171018d330525c94173d7d723df97f6bb`.

As lacunas observadas de Commons IO opcional, implementação Tiles e API JSP
transitiva foram mantidas para reprodução nos checkpoints funcionais e estão
explicitadas em `docs/legacy-dependencies.md`.

## Oracle JDBC

O contrato define `com.oracle.ojdbc7`, `oracle.jdbc.OracleDriver` e
`java:/jdbc/MigrationDS`. O template de módulo e a CLI de registro estão
versionados, mas o `ojdbc7.jar` continua externo e proibido no WAR. O
provisionamento e a conexão real entram no CP-1D.

## Validações executadas

```bash
bash -n scripts/doctor.sh scripts/validate-cp-1b.sh \
  scripts/audit-legacy-war.sh scripts/build-cp-1c.sh \
  scripts/validate-cp-1c.sh
./scripts/validate-cp-1b.sh --release
./scripts/validate-cp-1c.sh
./scripts/doctor.sh CP-1C --env .env
./scripts/build-cp-1c.sh --env .env
openspec validate create-java-web-migration-lab \
  --type change --strict --no-interactive
git diff --check
```

Resultados observados:

- `doctor` CP-1C: 47 verificações aprovadas, nenhuma falha ou aviso e oito
  itens futuros não exigidos;
- build normal e build com repositório Maven temporário vazio aprovados;
- repositório Maven vazio resolveu todas as dependências via HTTPS em
  aproximadamente um minuto;
- POM, contrato de datasource, shell, OpenSpec e recursos cumulativos
  aprovados;
- Maven 3.8.9 com Java 8u492 rejeitado deliberadamente pelo Enforcer, enquanto
  Java 7u80 foi aprovado;
- WAR com 14 bibliotecas, bytecode Java 7 e checksum estável.

## Reprodução em checkout limpo

Em 24 de julho de 2026, o commit `0e2b0bb` foi clonado em diretório
temporário. Depois de configurar somente a identidade Git, o clone passou nos
validadores cumulativos, no OpenSpec estrito, no `doctor` CP-1C e no build
auditado. O worktree continuou limpo porque `app/target` está ignorado. O WAR
reproduziu o mesmo SHA-256 registrado acima.

1. Configure a identidade Git e clone a branch ou o commit do PR.
2. Reutilize somente os runtimes externos aprovados e um JKS atualizado.
3. Crie `.env` a partir de `.env.example`.
4. Execute o `doctor`, o validador estático e o wrapper conforme acima.

O checkout não contém JDK, Maven, WildFly, truststore, driver Oracle,
credenciais, dependências baixadas nem WAR.

## Rollback

Antes do merge, feche o PR e remova somente a branch
`checkpoint/cp-1c-legacy-war`. Depois do merge, reverta o commit squash em novo
PR, sem reescrever `main`.

O rollback Git não remove `app/target` nem o cache Maven. Esses artefatos são
recriáveis e ignorados. Use `mvn clean` pelo wrapper para limpar `app/target`;
não remova a árvore ampla do usuário ou o repositório inteiro. O módulo Oracle
ainda não foi materializado pelo CP-1C.
