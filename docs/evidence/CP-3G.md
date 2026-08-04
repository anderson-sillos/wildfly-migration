# Evidência CP-3G — Substituições web

## Resultado

O CP-3G foi validado no Java 21/WildFly 41 com H2 portátil. As atividades
3.31–3.34 substituíram Tiles, Commons FileUpload, Reflections e a ponte de
logging, preservando os contratos HTTP e a fronteira do WAR. O gate portátil
executou 15 cenários, incluindo listagem, criação, detalhe, sessão, upload e
importação XML.

| Gate | Resultado | Evidência principal |
| --- | --- | --- |
| Layout JSP sem Tiles | `passed` | `validate-cp-3g-tiles.sh` |
| Multipart Servlet nativo | `passed` | `upload-ci-h2.json` |
| Descoberta SCI | `passed` | `discovery-ci-h2.json` |
| SLF4J/MyBatis no WildFly | `passed` | `logging-ci-h2.json` |
| Contratos web H2 | `15/15 passed` | smoke WildFly 41 / `closure.properties` |
| Auditoria de dependências e segurança | `passed` | `validate-cp-3g-closure.sh` |

O WAR final não empacota Tiles, Commons FileUpload, Reflections, a ponte
`log4j-over-slf4j`, a API SLF4J duplicada ou um backend de logging concorrente.
O JAR do `ServletContainerInitializer` e seu descritor de serviço permanecem
em `WEB-INF/lib`, enquanto os validadores concretos permanecem em
`WEB-INF/classes`.

## Limite da qualificação Oracle

A execução remota do CP-3G usa H2 para ser reproduzível sem acesso à rede
interna. A evidência Oracle versionada da atividade 3.32 comprova os 15
cenários de upload/XML com o mesmo WAR da atividade, mas não é apresentada como
uma execução Oracle completa do CP-3G. A qualificação Oracle de persistência e
logging permanece prevista para o CP-3H/CP-3I, com credenciais e schema
descartável disponíveis.

## Rollback

O rollback técnico retorna ao commit integrado do CP-3F
(`2e8df53b209db963e9a27026d9aca9124aa0ce37`) e ao WAR Jakarta anterior. Esse
rollback é de código/runtime; não executa DDL, não remove o schema Oracle e não
altera dados externos. A propriedade
`migration/evidence/CP-3G/rollback.properties` registra a verificação por
checkout documentado.

## Evidências versionadas

- [`closure.properties`](../../migration/evidence/CP-3G/closure.properties)
- [`rollback.properties`](../../migration/evidence/CP-3G/rollback.properties)
- [`upload-ci-h2.json`](../../migration/evidence/CP-3G/upload-ci-h2.json)
- [`upload-oracle.json`](../../migration/evidence/CP-3G/upload-oracle.json)
- [`discovery-ci-h2.json`](../../migration/evidence/CP-3G/discovery-ci-h2.json)
- [`logging-ci-h2.json`](../../migration/evidence/CP-3G/logging-ci-h2.json)

O commit-fonte testado foi `1f7a97b91d4790a7f5621ec9871fa7092b5ba716`, com
`workingTree=false`. A integração da PR usa a mensagem
`checkpoint(CP-3G): replace legacy web libraries`.
