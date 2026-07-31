# Evidência CP-3B — Dependências centrais

## Escopo atual

Este documento acompanha o checkpoint CP-3B. As atividades 3.6, 3.7 e 3.8
atualizam MyBatis, logging e upload de forma isolada; a descoberta de
validadores permanece inalterada até a atividade 3.9. A conclusão consolidada
do checkpoint será registrada no fechamento 3.10.

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

## Logging transicional — atividade 3.7

O commit de implementação
`c9a4ee17b3548e57bd3c5cc499051e34eeebcf9c` removeu
`log4j:log4j:1.2.14` e `log4j.properties`. Os imports antigos foram preservados
por `log4j-over-slf4j` 1.7.36, enquanto `slf4j-api` 1.7.36 e o backend JBoss
LogManager permaneceram fornecidos pelo WildFly 26.

Os perfis H2 e Oracle reproduziram o mesmo artefato:

- SHA-256 do WAR:
  `4f6eb8c63b1e7abb9d0c89c1020251686240b98d4901ce2150cc85262442d335`;
- SHA-256 da árvore Maven:
  `69d1e75eea4926cf6b28073e57e4ac465ccbff6c8dd3ed8599d5c039aac25f90`;
- SHA-256 de `log4j-over-slf4j-1.7.36.jar`:
  `0a7e032bf5bcdd5b2bf8bf2e5cf02c5646f2aa6fee66933b8150dbe84e651e8a`;
- 22 dependências Maven e 20 bibliotecas em `WEB-INF/lib`;
- nenhum `log4j-1.x`, `slf4j-api` ou backend concorrente no WAR.

A sonda executada nos dois bancos provocou uma violação de unicidade
controlada. A aplicação respondeu HTTP `503`, e o `server.log` preservou o
evento `legacy_order persistence_failure`, a categoria completa, o mesmo MDC
da requisição, o stack trace do MyBatis e sua cadeia de causas. Não foram
observados `WFLYLOG0100`, ausência de binding ou bindings concorrentes.

Os dois perfis também repetiram os 14 contratos HTTP com sucesso. Os relatórios
sanitizados são:

- `migration/evidence/CP-3B/logging-ci-h2.json`;
- `migration/evidence/CP-3B/logging-oracle.json`.

### Conclusão comprovada

Para o subconjunto de API usado pela aplicação (`Logger`, `MDC`, níveis e
sobrecarga com `Throwable`), Log4j 1 pode ser retirado no Java 17/WildFly 26
sem reescrever imediatamente todos os pontos de log. A ponte local encaminha
os eventos ao logging administrado pelo servidor e mantém correlação,
categorias e exceções completas em H2 e Oracle 19c.

Essa é uma solução de transição, não o destino final: a linha SLF4J 1.7 e os
imports `org.apache.log4j` continuam legados, e o isolamento do módulo é
específico do WildFly. Chamadas da aplicação real a appenders, configuradores
ou APIs Log4j fora do conjunto testado exigem inventário próprio. A atividade
3.34 removerá a ponte e fixará `logImpl=SLF4J`.

## Commons FileUpload 1.x — atividade 3.8

O commit de implementação
`64b5962e23a7d5dcb740c3a8d50a6ac172c8878f` substituiu FileUpload 1.2.2 por
1.6.0 e Commons IO 1.3.2 por 2.19.0, sem alterar o código de negócio nem
antecipar a troca de `javax.servlet` para `jakarta.servlet`.

Os perfis H2 e Oracle reproduziram o mesmo artefato:

- SHA-256 do WAR:
  `b199837b374d44cc84df1dcadbdfdf3ff53351201305c70828b9b2cc602fa3ff`;
- SHA-256 da árvore Maven:
  `c2386269619697e8e760514cfe33155d883ffab0af1302b87a37b7b7bdbd539f`;
- SHA-256 de `commons-fileupload-1.6.0.jar`:
  `9383272c93569afeabedb16923a94a6dc8a5bd7a2f9f83bf326af4ee68434629`;
- SHA-256 de `commons-io-2.19.0.jar`:
  `824268919b4b62f9f40f08c54381de5993b078f58667e332d17348ae019d72b9`;
- 22 dependências Maven e 20 bibliotecas em `WEB-INF/lib`;
- bytecode da aplicação Java 17, major `61`.

As sondas repetiram os 14 contratos HTTP e aprovaram o upload válido com nome
normalizado, o round-trip de conteúdo e metadados, o limite de 512 KiB por
arquivo, o limite de 576 KiB por requisição e a remoção dos temporários
`upload_*`. O H2 2.4.240 recebeu `portable-ci`; o Oracle Database 19c RU 19.3
recebeu `oracle-qualified`.

Os relatórios sanitizados são:

- `migration/evidence/CP-3B/upload-ci-h2.json`;
- `migration/evidence/CP-3B/upload-oracle.json`.

### Conclusão comprovada

Commons FileUpload 1.6.0 e Commons IO 2.19.0 podem substituir diretamente as
versões 1.2.2 e 1.3.2 no subconjunto usado por esta aplicação, preservando o
contrato `javax`, os limites, a persistência e a limpeza no Java 17/WildFly
26. A comprovação nos dois bancos mostra que a atualização de segurança pode
ser feita com baixo impacto antes da migração Jakarta.

Esta ainda é uma ponte: a linha 1.x mantém o parser externo e não cobre
factories personalizadas, listeners, streaming API ou serialização de
`FileItem` que existam somente na aplicação real. A atividade 3.32 fará a
substituição final por `@MultipartConfig` e `jakarta.servlet.http.Part`.

## Rollback

Para desfazer somente a atividade 3.8, retorne ao commit verde da atividade
3.7 `e73f3184917984062d9ce8037d75236631399d99`. Esse estado mantém MyBatis
3.5.19 e a ponte de logging, restaurando FileUpload 1.2.2 e Commons IO 1.3.2.

Para desfazer somente a atividade 3.7, retorne ao commit verde da atividade
3.6 `57d6e7630ef42a85b15e16aeb126a5027c67950d`. Esse estado mantém MyBatis
3.5.19 e restaura Log4j 1.2.14, `log4j.properties` e a allowlist anterior.

Para desfazer todo o CP-3B, retorne ao commit verde do CP-3A
`6d94e5fc735575fa2ac644690a2a0635d921199f`, que restaura MyBatis 3.4.5 e sua
allowlist sem alterar o schema ou os dados permanentes do laboratório.
