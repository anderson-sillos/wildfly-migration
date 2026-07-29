# Dependências do WAR legado

O CP-1C reproduz as versões informadas para a aplicação original. Elas não são
recomendações para produção nova: várias têm vulnerabilidades conhecidas ou
estão descontinuadas. O objetivo é congelar um baseline auditável antes de
atualizar cada componente.

## APIs fornecidas pelo WildFly

| Coordenada | Versão | Escopo |
| --- | --- | --- |
| `javax.servlet:servlet-api` | 2.4 | `provided` |
| `javax.servlet:jsp-api` | 2.0 | `provided` |
| `javax.servlet.jsp.jstl:jstl-api` | 1.2 | `provided` |

Essas APIs participam da compilação e são rejeitadas se aparecerem em
`WEB-INF/lib`. O descritor TLD informado pela aplicação real usa `version="2.0"`
e namespace Java EE histórico; “taglib 2.0” é uma versão de descritor, não uma
dependência Maven adicional.

## Bibliotecas empacotadas deliberadamente

| Coordenada | Versão |
| --- | --- |
| `org.mybatis:mybatis` | 3.4.5 |
| `log4j:log4j` | 1.2.14 |
| `commons-fileupload:commons-fileupload` | 1.2.2 |
| `commons-io:commons-io` | 1.3.2 |
| `org.reflections:reflections` | 0.9.10 |
| `org.apache.tiles:tiles-api` | 2.1.4 |
| `org.apache.tiles:tiles-jsp` | 2.1.4 |
| `org.apache.xmlbeans:xmlbeans` | 2.3.0 |
| `xml-apis:xml-apis` | 1.3.02 |
| `org.apache.geronimo.specs:geronimo-stax-api_1.0_spec` | 1.0 |
| `dom4j:dom4j` | 1.6.1 |

O arquivo `runtime/legacy/war-libraries.txt` fixa também a árvore transitiva
efetivamente observada. A presença simultânea de `stax-api`, Geronimo StAX e
`xml-apis` é preservada no baseline para que conflitos de classloader apareçam
naturalmente durante a migração.

### Lacunas preservadas e correções incrementais

O CP-1C não inventa dependências que não foram informadas para a aplicação
original. A árvore resolvida expôs três pontos que os próximos fluxos deverão
testar antes de corrigir:

- `commons-fileupload:1.2.2` marca `commons-io:1.3.2` como opcional; por isso
  `commons-io` não entrou automaticamente no WAR, embora classes de FileUpload
  o referenciem. A falha natural foi reproduzida no primeiro smoke do CP-1F e
  corrigida declarando exatamente `commons-io:1.3.2`;
- `tiles-api:2.1.4` fornece apenas a API, não a implementação completa de
  renderização. O problema foi reproduzido no início do CP-1E e corrigido com
  a menor mudança compatível com o legado: `tiles-jsp:2.1.4`, que inclui
  transitivamente `tiles-core`, `tiles-servlet`, `commons-digester` e
  `commons-beanutils`;
- `jstl-api:1.2` traz `javax.servlet.jsp:jsp-api:2.1` transitivamente em
  `provided`, enquanto o POM também declara a coordenada histórica
  `javax.servlet:jsp-api:2.0`.

Esses pontos não impediam o WAR estrutural do CP-1C, porque ainda não havia
fluxo funcional. A correção de Tiles entra somente quando o CP-1E passa a
renderizar JSPs; a lacuna do FileUpload continua reservada ao fluxo de upload.
Qualquer correção registra sintoma, causa, menor mudança e impacto no baseline.
A falha funcional do FileUpload está em
[`migration/steps/CP-1F-commons-fileupload-commons-io.md`](../migration/steps/CP-1F-commons-fileupload-commons-io.md).

## Driver Oracle

`ojdbc7.jar` não é uma dependência do POM nem uma biblioteca do WAR. O WildFly
o fornece pelo módulo externo `com.oracle.ojdbc7`; a aplicação usa o datasource
`java:/jdbc/MigrationDS`. Consulte `runtime/legacy/ojdbc7/README.md`.

## Plugins do build

O Maven executa sobre Java 7, portanto os plugins também precisam ter bytecode
compatível:

O Enforcer usa `[3.8.9]` para Maven. Sem perfil, e no perfil `oracle`, o range
Java permanece `[1.7.0-80]` depois da normalização do plugin. O perfil
`ci-h2` usa `[1.7,1.8)` para permitir a build Zulu 7u352, enquanto o `doctor`
fixa e verifica exatamente Zulu 7.56.0.11 CA; Java 8 ou superior continua
rejeitado.

| Plugin | Versão | Motivo |
| --- | --- | --- |
| Maven Enforcer | `3.0.0-M3` | última versão da linha compatível com Java 7 |
| Maven Compiler | `3.8.1` | última versão da faixa documentada para Java 7 |
| Maven WAR | `3.3.2` | última versão documentada para Java 7 |
| Maven Dependency | `3.1.2` | versão documentada para Java 7 |

Referências oficiais:

- <https://maven.apache.org/enforcer/maven-enforcer-plugin/plugin-info.html>
- <https://maven.apache.org/plugins/maven-compiler-plugin/plugin-info.html>
- <https://maven.apache.org/plugins/maven-war-plugin/plugin-info.html>
- <https://maven.apache.org/plugins/maven-dependency-plugin/plugin-info.html>

A incompatibilidade HTTPS observada no primeiro build e sua correção segura
estão registradas em
`migration/steps/CP-1C-legacy-build-https.md`.
