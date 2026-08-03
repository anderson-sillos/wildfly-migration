# CP-3C — remoção de APIs XML duplicadas

## Incompatibilidade observada

O gate Java 17 ainda empacotava xml-apis e Geronimo StAX, embora DOM, SAX,
JAXP e StAX já fossem fornecidos pelo módulo java.xml. A duplicação poderia
alterar resolução de classes conforme o classloader do WildFly.

## Correção aplicada

As duas dependências e suas propriedades de versão foram removidas do
app/pom.xml. A allowlist ativa do WildFly 26 foi regenerada; as allowlists
legadas continuam preservadas para não reescrever a história da migração.

## Evidência

    ./scripts/validate-cp-3c-java-xml.sh --env .env

O comando comprova ausência das APIs duplicadas no POM, na árvore Maven e no
WAR, além de verificar a origem java.xml das APIs no Java 17. O resultado
sanitizado está em migration/evidence/CP-3C/java-xml-ci-h2.json.

## Rollback

Reverter a entrega da atividade restaura as dependências XML duplicadas do
gate Java 17. Nenhum arquivo em target/ é recuperado ou versionado.
