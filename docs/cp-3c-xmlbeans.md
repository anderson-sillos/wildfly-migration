# CP-3C — XMLBeans 5.3.0 e tipos gerados

Esta atividade iniciou o CP-3C. XMLBeans e dom4j já foram atualizados; as APIs
XML duplicadas e o driver Oracle continuam nas versões do CP-3B até as
atividades 3.13–3.14.

## Decisão

O POM fixa `org.apache.xmlbeans:xmlbeans:5.3.0` e executa o plugin XMLBeans em
cada build. O arquivo
`app/src/main/resources/xsd/pedido-importacao-v1.xsd` é a fonte única dos
tipos: o plugin gera as interfaces, implementações e o `TypeSystemHolder` em
`target/`. Esses arquivos não são versionados, evitando que uma alteração do
XSD fique escondida em código gerado antigo.

O namespace `urn:wildfly-migration:pedido:1` é mapeado para o pacote gerado
`wildflyMigrationPedido1`. O `repackage` explícito evita que o hífen do
artifactId do Maven seja transformado em um identificador inválido de pacote.
O parser usa `PedidoDocument.Factory.parse` e `validate`; o mapeamento de
domínio agora usa dom4j 2.2.0 com o mesmo XMLReader seguro.

O `pluginManagement` também contém metadata do m2e para executar o goal
`xmlbeans:compile` durante a importação/compilação incremental do workspace.
Isso elimina o aviso “Plugin execution not covered by lifecycle configuration”
e faz o JDT reconhecer `target/generated-sources`; a configuração não é
executada como uma dependência nem altera o WAR no Maven CLI.

XMLBeans 5.3.0 traz `log4j-api:2.24.2` como dependência de API. O WAR mantém
essa API, mas não empacota `log4j-core` nem outro backend: no WildFly, o
backend continua sendo administrado pelo servidor. A mensagem de ausência de
provider que pode aparecer ao executar a sonda fora do servidor é esperada e
não muda a política de logging do WAR. A cópia transitiva `stax-api` deixa de
ser gerada; `xml-apis` e Geronimo StAX diretos foram removidos na atividade
3.13. A comprovação do módulo `java.xml` está em cp-3c-java-xml-apis.md.

## Verificação reproduzível

No ambiente aprovado do gate Java 17:

```bash
./scripts/validate-cp-3c-xmlbeans.sh --env .env
```

O comando constrói e audita o WAR e executa uma sonda sem WildFly ou banco que
comprova:

- tipos gerados no pacote `wildflyMigrationPedido1`;
- aceitação da fixture válida e rejeição da fixture inválida pelo XSD;
- namespace do elemento raiz antes e depois da serialização;
- round-trip `parse → xmlText → parse` preservando os valores gerados.

O resultado sanitizado fica em
`app/target/contract-results/cp-3c-xmlbeans-ci-h2.json` durante a execução.
A evidência versionada da atividade fica em
`migration/evidence/CP-3C/xmlbeans-ci-h2.json` após o commit da entrega.

O parsing dom4j é validado separadamente:

```bash
./scripts/validate-cp-3c-dom4j.sh --env .env
```

Essa sonda confirma documento legítimo, namespace, rejeição de XXE e rejeição
de expansão de entidades; o resultado fica em
`migration/evidence/CP-3C/dom4j-ci-h2.json`.

## Limites e rollback

Esta atividade não comprova a remoção das APIs XML antigas, nem a
compatibilidade do `ojdbc7` com o destino final. Ela também não altera o
contrato XML ou o namespace público.

O rollback é o commit imediatamente anterior à atividade 3.11: ele restaura
XMLBeans 2.3.0 e a compilação dinâmica histórica, sem alterar schema ou dados.

## Fontes primárias

- [Guia oficial do plugin Maven XMLBeans](https://xmlbeans.apache.org/guide/Maven.html);
- [Download e histórico oficial do XMLBeans 5.3.0](https://xmlbeans.apache.org/download/);
- [Tipos gerados e namespaces no XMLBeans](https://xmlbeans.apache.org/guide/GeneratedTypes.html);
- [dom4j 2.2.0 no Maven Central](https://repo1.maven.org/maven2/org/dom4j/dom4j/2.2.0/) e [SAXReader](https://dom4j.github.io/javadoc/2.0.3/org/dom4j/io/SAXReader.html).
