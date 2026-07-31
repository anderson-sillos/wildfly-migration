# CP-3C — dom4j 2.2.0 e parsing seguro

A atividade 3.12 substitui `dom4j:dom4j:1.6.1` por
`org.dom4j:dom4j:2.2.0`. A mudança inclui a coordenada Maven, mas preserva a
API usada pelo mapeamento (`SAXReader`, `Document`, `Element` e iteração dos
filhos), o namespace do pedido e os valores do documento.

O `SAXReader` recebe explicitamente um `XMLReader` criado por JAXP. O reader é
namespace-aware, usa processamento seguro, rejeita `DOCTYPE`, desabilita
entidades gerais e de parâmetro, impede DTD externo e instala um
`EntityResolver` que rejeita qualquer resolução externa. As opções de DTD do
dom4j também permanecem desabilitadas.

## Verificação

```bash
./scripts/validate-cp-3c-dom4j.sh --env .env
```

A sonda compila contra o JAR efetivo do WAR e comprova:

- documento legítimo com o mesmo elemento raiz, namespace e número do pedido;
- rejeição de `pedido-xxe.xml` sem leitura de arquivo local;
- rejeição de `pedido-entidades-expansivas.xml` sem expansão de entidades.

O resultado sanitizado é salvo em
`migration/evidence/CP-3C/dom4j-ci-h2.json`. A remoção de `xml-apis` e
Geronimo StAX permanece isolada na atividade 3.13, para que esta troca não
misture a resolução das APIs do módulo `java.xml`.

## Fontes

- [dom4j 2.2.0 no Maven Central](https://repo1.maven.org/maven2/org/dom4j/dom4j/2.2.0/);
- [SAXReader dom4j](https://dom4j.github.io/javadoc/2.0.3/org/dom4j/io/SAXReader.html), incluindo a configuração explícita do `XMLReader`.
