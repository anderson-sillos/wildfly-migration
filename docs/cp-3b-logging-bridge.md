# CP-3B — Ponte temporária de logging

## Decisão da atividade 3.7

O gate Java 17/WildFly 26 remove `log4j:log4j:1.2.14` sem reescrever de uma
vez todos os imports `org.apache.log4j` da aplicação. O caminho transitório é:

```text
chamadas org.apache.log4j existentes
  -> log4j-over-slf4j 1.7.36 no WAR
  -> slf4j-api 1.7.36 fornecida pelo WildFly
  -> slf4j-jboss-logmanager
  -> JBoss LogManager administrado pelo servidor
```

`log4j-over-slf4j` é uma ponte de compatibilidade, não um backend. A linha
SLF4J 1.7 é usada aqui porque corresponde à API fornecida pelo WildFly
26.1.3.Final. Ela não é o destino final e será removida na atividade 3.34,
quando o código usará diretamente a fachada escolhida e o MyBatis fixará
`logImpl=SLF4J`.

## Isolamento do classloader

O WildFly 26 contém o módulo público depreciado `org.apache.log4j`, ligado ao
adaptador `log4j-jboss-logmanager`. Dependências implícitas do servidor têm
precedência sobre bibliotecas locais; sem isolamento, o JAR
`log4j-over-slf4j` poderia ser empacotado e nunca ser carregado.

Por isso, `WEB-INF/jboss-deployment-structure.xml` exclui somente
`org.apache.log4j`. A aplicação continua enxergando o módulo `org.slf4j`
fornecido pelo servidor. O WAR contém a ponte, mas não contém:

- `log4j-1.x`;
- `slf4j-api`;
- `slf4j-simple` ou `slf4j-log4j12`;
- Logback;
- `log4j-core`.

Essa exclusão é específica do gate WildFly e deve ser reavaliada numa troca
de servidor. Ela não altera a API de logging usada pelo código legado.

## Configuração fora do WAR

`log4j.properties` foi removido. Os perfis H2 e Oracle configuram no subsistema
de logging do WildFly:

- a categoria `br.com.asillos.migration` em nível `INFO`;
- um formatter compartilhado para o handler `CONSOLE`;
- `%X{correlationId}` para preservar o MDC no `server.log`.

Isso elimina o aviso `WFLYLOG0100` e mantém a configuração operacional fora do
artefato da aplicação. Como o laboratório cria um WildFly temporário para cada
execução, os arquivos `.cli` são a fonte reproduzível dessa configuração.

## Validação reproduzível

```bash
./scripts/qualify-cp-3b-h2.sh --env .env
./scripts/qualify-cp-3b-oracle.sh --env .env
```

Além dos 14 contratos HTTP, a qualificação cria intencionalmente uma violação
de unicidade já tratada pela fronteira web. O teste exige HTTP `503` e confirma
no `server.log`:

- categoria completa do logger;
- mesmo identificador de correlação enviado no cabeçalho;
- evento `legacy_order persistence_failure`;
- stack trace do MyBatis e cadeia `Caused by`;
- ausência de `WFLYLOG0100` e de conflito entre bindings.

Os relatórios sanitizados são
`cp-3b-logging-ci-h2.json` e `cp-3b-logging-oracle.json`. Eles registram apenas
versões, checksums e estados dos checks; não registram o log bruto, URL,
usuário ou senha do Oracle.

## Limite da comprovação

O gate comprova os usos representados no laboratório: `Logger`, `MDC`,
categorias, níveis `INFO`/`WARN`/`ERROR` e sobrecarga com `Throwable`. Uma
aplicação real deve inventariar chamadas a appenders, configuradores ou APIs
específicas do Log4j 1; essas APIs podem não existir na ponte e exigem
correção localizada.
