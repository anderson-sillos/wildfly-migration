# Evidência CP-3F — Namespaces e descritores Jakarta

## Estado atual

As tarefas 3.26–3.28 foram implementadas e validadas estaticamente. O build
Java 21/Jakarta EE 11 passa, e o TLD histórico 2.0 foi preservado antes da
conversão para o descritor Jakarta 3.0.

| Verificação | Resultado |
| --- | --- |
| Imports EE web | `jakarta.servlet.*` e `jakarta.servlet.jsp.*` |
| APIs Java SE | `javax.sql`, `javax.naming` e `javax.xml` preservadas |
| `web.xml` | Jakarta EE / Servlet 6.1 |
| JSTL | `jakarta.tags.core` e `jakarta.tags.fmt` |
| TLD | URI preservado; schema Jakarta JSP 3.0 |
| Build | Java 21 + Jakarta EE 11: `passed` |

## Bloqueio identificado

A tentativa de implantação do WAR compilado no WildFly 41 falha antes dos
contratos web porque o `TilesListener` ainda referencia
`javax.servlet.ServletContextListener`. Isso confirma a fronteira já prevista
no gate Java 17: Tiles não tem uma linha Jakarta mantida e precisa ser
substituído por includes/tag files na atividade 3.31.

O bloqueio é registrado, não mascarado por uma dependência `javax` adicional no
WAR. A execução de listagem, criação, consulta e sessão será repetida depois da
remoção do Tiles, preservando a ordem causal da migração.

## Evidências versionadas

- [`jakarta-build.json`](../../migration/evidence/CP-3F/jakarta-build.json)
- [`jakarta-build.txt`](../../migration/evidence/CP-3F/jakarta-build.txt)
- [`tld-historical.xml`](../../migration/evidence/CP-3F/tld-historical.xml)
- [`tld-migration.properties`](../../migration/evidence/CP-3F/tld-migration.properties)
- [`validate-cp-3f-namespace.sh`](../../scripts/validate-cp-3f-namespace.sh)

O CP-3F ainda não está encerrado. Seu rollback é o estado verde do CP-3E;
após a decisão de sequência, o checkpoint deverá produzir a evidência de
contratos e o commit `checkpoint(CP-3F): migrate Jakarta namespaces`.
