# CP-3D — Gate Java 17: exceção Tiles e TLD

## Decisão da atividade 3.16

O gate Java 17/WildFly 26.1.3 mantém exatamente Apache Tiles 2.1.4 e o
handler TLD 2.0 em `javax.servlet.jsp.tagext`. Esta é uma exceção temporária de
compatibilidade, não uma recomendação para produção e não uma atualização de
Tiles.

A decisão preserva o comportamento aprovado no CP-3C e evita misturar o gate
de Java 17/EE 8 com a migração de namespace e de arquitetura prevista para o
Jakarta EE 11. O Apache Tiles está descontinuado; trocar 2.1.4 por outra linha
também descontinuada não reduziria o risco nem forneceria suporte mantido.

## Limites congelados

- `org.apache.tiles:tiles-api` e `org.apache.tiles:tiles-jsp` permanecem em
  `2.1.4` no `app/pom.xml`;
- as transitivas `tiles-core` e `tiles-servlet` permanecem em `2.1.4`;
- o WAR do gate contém somente os quatro JARs Tiles 2.1.4 previstos na
  allowlist `runtime/phase3/java17-wildfly26/war-libraries.txt`;
- `migration.tld` conserva namespace Java EE histórico, schema
  `web-jsptaglibrary_2_0.xsd` e `version="2.0"`;
- `StatusPedidoTag` continua importando
  `javax.servlet.jsp.tagext.SimpleTagSupport`;
- `web.xml` conserva `TilesListener`, `tiles-defs.xml` e as URIs Tiles;
- nenhuma dependência Tiles adicional, versão mais nova ou API `jakarta.*` é
  introduzida neste gate.

A validação estática está em
[`scripts/validate-cp-3d-tiles-tld.sh`](../scripts/validate-cp-3d-tiles-tld.sh)
e a decisão operacional da incompatibilidade está em
[`migration/steps/CP-3D-tiles-tld-exception.md`](../migration/steps/CP-3D-tiles-tld-exception.md).

## Fronteira para os gates seguintes

Esta exceção termina antes do destino final. A atividade 3.28 captura primeiro
o comportamento do TLD histórico no WildFly 41 e migra o handler para
`jakarta.servlet.jsp.tagext`; a atividade 3.31 substitui Tiles por JSP tag
files ou includes protegidos sob `WEB-INF`. O CP-3H rejeitará qualquer JAR Tiles
no WAR final.

## Reprodução em uma aplicação real

1. inventarie a versão efetiva de `tiles-api`, `tiles-jsp`, `tiles-core` e
   `tiles-servlet` na árvore e no WAR;
2. confirme o namespace do TLD, a versão do descritor, os handlers e o listener
   de inicialização no descritor web;
3. registre o comportamento do layout antes de qualquer migração de namespace;
4. mantenha a exceção somente durante o gate `javax` e planeje a substituição
   por componentes JSP nativos no gate Jakarta.

## Rollback

A atividade não altera código de execução nem o schema. Para desfazer somente
esta decisão, reverta o commit do checkpoint por um novo PR e retorne ao
commit integrado do CP-3C (`314109417c648ce9d32ab3824d24696ac7c83a94`), depois
reexecute a auditoria do WAR. O rollback não deve atualizar Tiles para outra
versão EOL nem apagar dados do Oracle.

