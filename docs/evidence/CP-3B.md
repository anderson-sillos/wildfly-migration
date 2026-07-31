# Evidência CP-3B — Dependências centrais

## Escopo atual

Este documento acompanha o checkpoint CP-3B. A atividade 3.6 atualiza somente
MyBatis; logging, upload e descoberta de validadores permanecem inalterados
até as atividades 3.7, 3.8 e 3.9. A conclusão consolidada do checkpoint será
registrada no fechamento 3.10.

## MyBatis 3.5.19 — atividade 3.6

O commit de implementação
`d5f8a08242d4cdd18595a97e010954f1ee29f2f3` foi construído separadamente nos
perfis H2 e Oracle. Os dois builds reproduziram o mesmo WAR:

- SHA-256 do WAR:
  `94a6c0d81951cb47f591927222b2a070756ba9b9c67ed2925e88946727ae9106`;
- SHA-256 da árvore Maven:
  `205cfc8bf26fe7a9905f9ba5bfe85e385ab74a424cb8efc2aac219ea7b02efad`;
- SHA-256 de `mybatis-3.5.19.jar`:
  `93eea616ae355751bd5fbabb57f0732713fbe79f3196f33c51a0aeeb4255862a`;
- bytecode da aplicação Java 17, major `61`;
- bytecode do MyBatis Java 8, major `52`, compatível com o gate Java 17;
- 20 bibliotecas em `WEB-INF/lib`, sem driver H2 ou Oracle.

A comparação da árvore e da allowlist mostra uma substituição direta:
`mybatis-3.4.5.jar` saiu e `mybatis-3.5.19.jar` entrou. Nenhum JAR transitivo
novo foi empacotado. A allowlist da fase 2 permaneceu inalterada.

As duas sondas carregaram `PedidoMapper` e `AnexoMapper`, resolveram os aliases
`pedido` e `anexo`, selecionaram os type handlers de status e SHA-256 e
exercitaram `MetaClass`/`MetaObject` sobre `Pedido.numero`. Também aprovaram
commit em nova sessão e rollback depois de uma falha intencional.

No H2 2.4.240, o resultado foi classificado como `portable-ci`. No Oracle
Database 19c RU 19.3, a mesma revisão recebeu `oracle-qualified` e aprovou
adicionalmente round-trip de `TIMESTAMP(6)` e BLOB com o `ojdbc7` externo.
As duas execuções repetiram os 14 contratos HTTP, todos aprovados.

Os relatórios sanitizados são:

- `migration/evidence/CP-3B/mybatis-ci-h2.json`;
- `migration/evidence/CP-3B/mybatis-oracle.json`.

### Conclusão comprovada

MyBatis 3.5.19 pode substituir diretamente a versão 3.4.5 nesta aplicação no
Java 17/WildFly 26 sem alterar mappers, aliases, type handlers, SQL,
repositórios ou limites transacionais. O resultado comprova o comportamento
exercitado em H2 e Oracle 19c, não uma garantia automática para mappers ou
extensões da aplicação real que não estejam representados no laboratório.

`logImpl` continua deliberadamente implícito nesta atividade. A atualização de
logging permanece separada nas atividades 3.7 e 3.34.

## Rollback

O rollback retorna ao commit verde do CP-3A
`6d94e5fc735575fa2ac644690a2a0635d921199f`, que restaura MyBatis 3.4.5 e sua
allowlist sem alterar o schema ou os dados permanentes do laboratório.
