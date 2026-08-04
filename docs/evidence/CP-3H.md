# Evidência CP-3H — Oracle e empacotamento final do gate Jakarta

## Resultado comprovado

O CP-3H fecha o gate Java 21/WildFly 41 da fase final. A mesma aplicação e o
mesmo WAR foram validados em H2 portátil e qualificados no Oracle 19c, com
auditorias independentes para XML, datasource, dependências e empacotamento.

| Verificação | Resultado | Evidência |
| --- | --- | --- |
| H2 portátil | `15/15 passed` | [`closure-portable-ci.json`](../../migration/evidence/CP-3H/closure-portable-ci.json) |
| Oracle 19c | `15/15 passed` | [`closure-oracle-qualified.json`](../../migration/evidence/CP-3H/closure-oracle-qualified.json) |
| XMLBeans/dom4j seguro | `passed` | [`xml-ci-h2.json`](../../migration/evidence/CP-3H/xml-ci-h2.json) |
| Datasources e pools | `passed` | [`datasource-ci-h2.json`](../../migration/evidence/CP-3H/datasource-ci-h2.json) e [`datasource-oracle.json`](../../migration/evidence/CP-3H/datasource-oracle.json) |
| Dependências e WAR | `passed` | [`packaging-audit.json`](../../migration/evidence/CP-3H/packaging-audit.json) |

O ambiente Oracle observado foi Database 19c com versão completa/RU
`19.3.0.0.0`, driver `ojdbc17-23.26.2.0.0`, Temurin 21.0.12+8 e WildFly
41.0.0.Final (Core 33.0.0.Final). O datasource publicado nos dois perfis é
`java:/jdbc/MigrationDS`; H2 permanece somente no runtime de teste e o driver
Oracle permanece como módulo do servidor, fora do WAR.

## Empacotamento e segurança

O WAR não contém APIs do contêiner, H2, OJDBC, `ojdbc7`, Log4j 1 ou ponte,
Tiles, Commons FileUpload, Reflections, scanners externos, `xml-apis` ou
Geronimo StAX. A auditoria também confirma o JAR interno do
`ServletContainerInitializer`, seu descritor de serviço e os validadores
concretos em suas localizações corretas.

XMLBeans 5.3.0 regenera os tipos a partir do XSD e dom4j 2.2.0 rejeita schema
inválido, XXE e expansão de entidades. MyBatis 3.5.19 usa o datasource JNDI e
`logImpl=SLF4J` sem backend concorrente empacotado.

H2 comprova a trilha portátil, o contrato HTTP e a integração JNDI/MyBatis;
não substitui a qualificação dos recursos específicos do Oracle. Por isso os
resultados permanecem em relatórios separados.

## Rollback

O retorno ao CP-3G está registrado em
[`rollback.properties`](../../migration/evidence/CP-3H/rollback.properties).
O rollback é feito por checkout do commit verde anterior e não executa DDL,
não remove schema e não altera dados do Oracle.

## Rastreabilidade

O resumo dos gates e o resultado `passed` estão em
[`closure.properties`](../../migration/evidence/CP-3H/closure.properties).
Ambos os relatórios finais apontam para commits-fonte existentes e para o mesmo
WAR. Os commits podem ser diferentes porque a qualificação Oracle é executada
em uma rede interna separada da execução portátil H2. Cada relatório registra
`workingTree=false`, permitindo reproduzir o estado sem depender de alterações
locais não versionadas.
