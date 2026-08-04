# CP-3G / atividade 3.34 — logging final com SLF4J

O gate Java 17 usava `log4j-over-slf4j` apenas para preservar os imports
`org.apache.log4j` durante a transição. Essa ponte não é o destino final e não
deve permanecer no WAR Jakarta.

## Alteração

- os cinco pontos de logging da aplicação usam `org.slf4j.Logger` e
  `LoggerFactory`;
- o filtro de correlação usa `org.slf4j.MDC`;
- `mybatis-config.xml` define explicitamente `logImpl=SLF4J`;
- o POM mantém somente `slf4j-api:2.0.18` em `provided`, alinhado à API
  fornecida pelo WildFly 41;
- o WAR não empacota ponte, API SLF4J duplicada, Log4j 1 ou backend próprio;
- os perfis do WildFly elevam a categoria de persistência a `DEBUG` para
  comprovar as categorias dos mappers e mantêm o `correlationId` no padrão.

O `jboss-deployment-structure.xml` permanece somente como descritor vazio para
preservar a estrutura do WAR; não há exclusões ou módulos de logging legados.

## Verificação

```bash
./scripts/validate-cp-3g-logging.sh \
  --war app/target/wildfly-migration.war \
  --server-log app/target/contract-results/cp-3g-wildfly41.log
```

O smoke inicia o WildFly 41, executa os contratos, registra chamadas dos
mappers e provoca uma violação de unicidade controlada depois dos contratos. A
transação sofre rollback e a resposta HTTP permanece sanitizada, enquanto o `server.log` deve conter a
categoria do mapper, o evento `legacy_order persistence_failure` e a cadeia de
stack trace completa. Nenhum segredo ou URL Oracle é incluído na evidência.

## Evidência e rollback

O relatório portátil fica em
`migration/evidence/CP-3G/logging-ci-h2.json`. A evidência registra o commit,
checksum do WAR, runtime, `logImpl`, ausência da ponte e os marcadores de
logging observados.

Para voltar ao gate anterior, restaure a revisão do CP-3F/CP-3G anterior à
atividade 3.34. Isso reintroduz apenas a configuração transitória documentada;
nenhum schema ou dado Oracle é alterado.
