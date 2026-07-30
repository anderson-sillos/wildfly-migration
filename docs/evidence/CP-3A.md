# Evidência CP-3A — Entrada no Java 17

## Escopo atual

Esta página registra inicialmente a atividade 3.1: executar o estado público
e imutável `migration/02-java8-wildfly26` no mesmo WildFly 26.1.3.Final,
trocando somente a JVM do servidor para Java 17. As atividades 3.2 a 3.5
completarão este documento sem reclassificar H2 como qualificação Oracle.

## Materialização da entrada

A tag foi materializada em um Git worktree destacado no commit
`0440337d2256581666994f3192bf6c3516ce590e`, com status limpo. Dentro desse
worktree, Temurin 8u492-b09 e Maven 3.9.16 reconstruíram o WAR e a árvore Maven
da fase 2.

Os resultados reproduziram exatamente o manifesto aprovado:

- WAR SHA-256
  `62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2`;
- árvore Maven SHA-256
  `8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca`;
- bytecode Java 8, major `52`;
- 20 bibliotecas em `WEB-INF/lib`.

Nenhum fonte, POM, descritor, biblioteca ou byte do WAR foi alterado para a
tentativa.

## Tentativa no runtime seguinte

O harness iniciou uma cópia temporária do WildFly 26 em loopback usando
Eclipse Temurin OpenJDK 17.0.20+8 e implantou diretamente o WAR da tag:

```bash
git worktree add --detach /tmp/wildfly-migration-cp3a-phase2 \
  migration/02-java8-wildfly26

/tmp/wildfly-migration-cp3a-phase2/scripts/build-cp-2c.sh \
  --profile ci-h2 \
  --env /caminho/seguro/wildfly-migration.env

MIGRATION_SOURCE_COMMIT=0440337d2256581666994f3192bf6c3516ce590e \
  ./scripts/smoke-wildfly9-datasource.sh \
    --server 26 \
    --java 17 \
    --profile ci-h2 \
    --env /caminho/seguro/wildfly-migration.env \
    --war /tmp/wildfly-migration-cp3a-phase2/app/target/wildfly-migration.war \
    --contract-result app/target/contract-results/cp-3a-before-ci-h2.json
```

Uma tentativa preliminar dentro do sandbox encontrou
`java.net.SocketException: Operation not permitted` ao enumerar interfaces.
Ela foi descartada como limitação do executor, pois ocorreu antes da aplicação.
A execução válida abriu somente as portas de loopback documentadas.

## Conclusão comprovada

O WAR Java 8 da fase 2 iniciou sem correção no Java 17/WildFly 26. O servidor,
o deployment e `java:/jdbc/MigrationDS` ficaram ativos, e os 14 contratos
portáteis passaram: saúde, listagem, criação, detalhe, sessão, upload e limite,
formulário e importação XML, rejeições XML/validator/XXE/expansão e estado
persistido.

A descoberta Reflections preservou o conjunto e a ordem dos validadores; não
foram observados `ClassNotFoundException`, `NoClassDefFoundError`,
`LinkageError`, `InaccessibleObjectException` ou
`UnsupportedClassVersionError`. O aviso conhecido `WFLYLOG0100` do Log4j 1
permaneceu e continua classificado como `INC-008`, adiado ao CP-3B.

Isso comprova compatibilidade de execução portátil do binário anterior, não
compatibilidade de recompilação com o JDK 17, suporte oficial de cada
dependência nem comportamento Oracle. A atividade 3.2 ainda deve executar o
build com Java 17 e verificar se alguma correção mínima é necessária. A
qualificação Oracle permanece pendente para o encerramento do CP-3A.

As evidências legíveis por máquina estão em
`migration/evidence/CP-3A/before-runtime.properties` e
`migration/evidence/CP-3A/contract-before-ci-h2.json`.

## Rollback

A tentativa usa somente um worktree destacado, uma cópia temporária do
WildFly e H2 em memória. O rollback consiste em encerrar o runtime temporário e
remover o worktree criado para a tag. A branch, a instalação externa do
WildFly, o WAR aprovado e o schema Oracle não são alterados.
