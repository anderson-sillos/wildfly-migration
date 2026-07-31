# Perfis do gate Java 17/WildFly 26

Os dois perfis publicam o mesmo pool `MigrationDS` no JNDI
`java:/jdbc/MigrationDS`, mas não compartilham driver nem credenciais.

- `ci-h2.cli` usa H2 2.4.240 como módulo externo, banco somente em memória e
  resultado `portable-ci`;
- `oracle.cli` mantém temporariamente o módulo externo `ojdbc7` e pode produzir
  resultado `oracle-qualified` somente após a suíte na rede interna.

O H2 não abre console, listener TCP ou arquivo persistente. Nenhum driver pode
ser empacotado em `WEB-INF/lib`.

Os dois perfis também configuram a mesma categoria
`br.com.asillos.migration`, o formatter `MIGRATION_PATTERN` e o campo MDC
`correlationId`. Assim, o comportamento de logging não depende de um
`log4j.properties` dentro do WAR.
