# CP-3C — APIs XML fornecidas pelo Java 17

A atividade 3.13 remove xml-apis:xml-apis:1.3.02 e
org.apache.geronimo.specs:geronimo-stax-api_1.0_spec:1.0 do POM ativo do
gate Java 17. As allowlists do baseline legado e da fase 2 permanecem
inalteradas para preservar a comparação histórica.

## Decisão

DOM, SAX, JAXP e StAX são APIs do módulo java.xml do JDK 17. Não há código
da aplicação que precise substituir esses imports por outra biblioteca. O
POM não declara mais as APIs duplicadas, a árvore de dependências não as
contém e nenhuma delas é empacotada no WAR.

## Verificação reproduzível

    ./scripts/validate-cp-3c-java-xml.sh --env .env

O script:

- constrói e audita o WAR do perfil ci-h2;
- rejeita as coordenadas antigas no POM;
- rejeita xml-apis, Geronimo StAX e stax-api na árvore Maven e em
  WEB-INF/lib;
- instancia XMLConstants, DOM, SAX, StAX e JAXP no Java 17 e verifica que
  todas as classes vêm do módulo java.xml;
- executa jdeps sobre LegacyPedidoXmlParser.class e exige java.xml.

O resultado sanitizado fica em
migration/evidence/CP-3C/java-xml-ci-h2.json. A última execução local
produziu um WAR de 17 bibliotecas com SHA-256
0b277886c54370e150310ba74117abd8bd1258fca9fe634dfc21383c5ba25063.

## Rollback

O rollback retorna ao último commit verde do CP-3B e restaura somente as
dependências XML duplicadas no gate Java 17. As allowlists históricas não são
alteradas.
