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
| Contratos H2 | WildFly 41 + H2 2.4.240: 15/15 `passed` |
| Contratos Oracle | WildFly 41 + Oracle 19c/ojdbc17: 15/15 `passed` |

## Bloqueio histórico identificado

A primeira tentativa de implantação do WAR compilado no WildFly 41 falhou
antes dos contratos web porque o `TilesListener` ainda referenciava
`javax.servlet.ServletContextListener`. Isso confirmou a fronteira prevista no
gate Java 17 e permanece registrado como evidência negativa reproduzível.

O bloqueio foi registrado, não mascarado por uma dependência `javax` adicional
no WAR. A atividade 3.31 removeu Tiles por tag file JSP/includes sob `WEB-INF`.
A execução posterior em H2 e Oracle no WildFly 41 concluiu os contratos de
listagem, criação, consulta, sessão, upload e importação XML. Os relatórios
sanitizados foram versionados com o commit testado `39b8be7`.

## Evidências versionadas

- [`jakarta-build.json`](../../migration/evidence/CP-3F/jakarta-build.json)
- [`jakarta-build.txt`](../../migration/evidence/CP-3F/jakarta-build.txt)
- [`contract-ci-h2.json`](../../migration/evidence/CP-3F/contract-ci-h2.json)
- [`contract-oracle.json`](../../migration/evidence/CP-3F/contract-oracle.json)
- [`manifest.properties`](../../migration/evidence/CP-3F/manifest.properties)
- [`closure.properties`](../../migration/evidence/CP-3F/closure.properties)
- [`rollback.properties`](../../migration/evidence/CP-3F/rollback.properties)
- [`tld-historical.xml`](../../migration/evidence/CP-3F/tld-historical.xml)
- [`tld-migration.properties`](../../migration/evidence/CP-3F/tld-migration.properties)
- [`validate-cp-3f-namespace.sh`](../../scripts/validate-cp-3f-namespace.sh)
- [`validate-cp-3g-tiles.sh`](../../scripts/validate-cp-3g-tiles.sh)
- [`validate-cp-3f-closure.sh`](../../scripts/validate-cp-3f-closure.sh)

O CP-3F está encerrado. As evidências H2 e Oracle foram executadas com
`workingTree=false`, no commit integrado `39b8be7`, e o rollback é o estado
verde do CP-3E. O commit de integração é
`checkpoint(CP-3F): migrate Jakarta namespaces`.
