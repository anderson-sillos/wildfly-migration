# CP-3C — Atualização do XMLBeans para 5.3.0

## Estado anterior

O parser carregava o XSD em runtime com `XmlBeans.loadXsd`, usando
XMLBeans 2.3.0. Essa abordagem deixava a compilação do schema dependente do
classpath do servidor e não produzia tipos Java verificáveis durante o build.

## Alteração

O POM agora fixa XMLBeans 5.3.0 e o plugin XMLBeans gera os tipos a partir de
`pedido-importacao-v1.xsd`. O namespace é reempacotado para
`wildflyMigrationPedido1`, e `LegacyPedidoXmlParser` usa
`PedidoDocument.Factory.parse` com as mesmas proteções contra DTD e entidades
externas. O mapeamento dom4j fica deliberadamente inalterado para ser tratado
na atividade 3.12.

O metadata `org.eclipse.m2e:lifecycle-mapping` executa esse goal também no
workspace Maven do VS Code. Sem ele, o Maven CLI continua funcionando, mas o
m2e acusa execução não coberta e não adiciona os fontes gerados ao classpath
do JDT.

A allowlist do WAR foi atualizada para `xmlbeans-5.3.0.jar` e
`log4j-api-2.24.2.jar`; não há `log4j-core` e não há `stax-api` transitivo.
As dependências XML diretas legadas ainda presentes são uma pendência
explícita da atividade 3.13.

## Verificação

```bash
./scripts/validate-cp-3c-xmlbeans.sh --env .env
```

A sonda compila contra os tipos gerados e testa fixture válida, rejeição por
schema, namespace e round-trip de serialização. O build também executa a
auditoria do WAR e impede APIs de contêiner, driver ou backend de logging no
artefato.

## Rollback

Reverter a entrega desta atividade restaura a geração dinâmica do XMLBeans
2.3.0. Nenhum arquivo em `target/` deve ser recuperado ou versionado no
rollback.
