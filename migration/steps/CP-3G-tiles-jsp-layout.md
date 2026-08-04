# CP-3G/3.31 — substituir Tiles por layout JSP

## Sintoma reproduzido

O WAR Jakarta compilava, mas o WildFly 41 rejeitava o deployment ao carregar
`org.apache.tiles.web.startup.TilesListener`, cuja assinatura exige
`javax.servlet.ServletContextListener`.

## Correção mínima

1. remover o listener e o parâmetro de definições de Tiles do `web.xml`;
2. remover `tiles-api`, `tiles-jsp` e suas transitivas do POM;
3. transformar o template em `WEB-INF/tags/layout/page.tag`;
4. trocar cada `tiles:insertDefinition` por uma chamada `layout:page` que
   inclui o fragmento de conteúdo correspondente;
5. manter cabeçalho, rodapé, estilos e atributos de requisição nos mesmos
   fragments protegidos.

## Teste de regressão

O script `scripts/validate-cp-3g-tiles.sh` verifica o conteúdo fonte e o WAR.
O smoke `scripts/smoke-wildfly41-datasource.sh --profile ci-h2` inicia o
WildFly 41 em loopback, configura o datasource H2, implanta o WAR e executa a
suíte HTTP externa. O resultado esperado é `portable-ci`, com todos os
cenários funcionais aprovados.

## Aplicação equivalente em produção

Em uma aplicação real, capture primeiro as definições e regiões renderizadas
por Tiles. Converta cada definição para um tag file ou include sob `WEB-INF`,
preserve os nomes de atributos usados pelos controllers e compare HTML,
status HTTP, sessão e cabeçalhos. Não resolva a incompatibilidade adicionando
APIs `javax.servlet` ao servidor Jakarta.

## Rollback

O rollback é o WAR aprovado do CP-3D e suas dependências Tiles 2.1.4. Ele deve
ser feito como alteração isolada, sem desfazer a migração de namespace já
validada no CP-3F.
