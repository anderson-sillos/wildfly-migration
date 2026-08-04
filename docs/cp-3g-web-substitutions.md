# CP-3G — Substituições web no Jakarta

## Atividade 3.31: remoção do Tiles

Apache Tiles 2.1.4 foi mantido como exceção no gate Java 17 porque a biblioteca
está descontinuada e depende de `javax.servlet`. No WildFly 41/Jakarta EE 11,
essa dependência impede o deployment antes de qualquer contrato web. A solução
de menor impacto é preservar as mesmas regiões do layout com recursos nativos
de JSP:

- `WEB-INF/tags/layout/page.tag` concentra o documento HTML, estilos,
  cabeçalho, conteúdo e rodapé;
- as páginas públicas continuam sendo wrappers pequenos e passam apenas o
  título e o caminho do conteúdo ao tag file;
- `header.jsp` e `footer.jsp` continuam fragmentos protegidos sob `WEB-INF`;
- `tiles-defs.xml`, `base.jsp` e as dependências `tiles-api`/`tiles-jsp` são
  removidos.

O uso de `WEB-INF` mantém os fragments e tag files fora do acesso HTTP direto.
O URI e o handler da tag customizada do projeto não fazem parte da troca de
layout e permanecem validados pelo CP-3F.

## Verificação reproduzível

```bash
./scripts/validate-cp-3g-tiles.sh
./scripts/rebuild-cp-3f-ide.sh --env .env
./scripts/smoke-wildfly41-datasource.sh \
  --profile ci-h2 --env .env \
  --war app/target/wildfly-migration.war \
  --result /tmp/cp3f-h2-contract.json
```

A validação estática rejeita qualquer referência a Tiles no POM, descritor,
JSP ou WAR. O smoke H2 comprova que listagem, criação, detalhe, sessão,
upload, página de importação XML e os cenários XML continuam funcionando no
WildFly 41 com Java 21. A qualificação Oracle permanece separada e depende do
schema descartável e das credenciais do ambiente.

A mesma suíte confirma que `WEB-INF/tags/layout/page.tag` e os fragments não
respondem a acesso HTTP direto (`403` ou `404`).

Para a atividade 3.32, os relatórios sanitizados H2 e Oracle ficam em
[`migration/evidence/CP-3G/upload-ci-h2.json`](../migration/evidence/CP-3G/upload-ci-h2.json)
e
[`migration/evidence/CP-3G/upload-oracle.json`](../migration/evidence/CP-3G/upload-oracle.json).
Ambos registram 15/15 cenários aprovados, o mesmo WAR e `workingTree=false` no
commit integrado do CP-3F.

## Fechamento do checkpoint

Reflections e a ponte temporária de logging continuam transições deliberadas.
Commons FileUpload já foi removido na atividade 3.32 e substituído por
`@MultipartConfig`/`jakarta.servlet.http.Part`; a decisão e os limites
preservados estão em
[`CP-3G-servlet-multipart.md`](../migration/steps/CP-3G-servlet-multipart.md).
As atividades 3.33–3.34 foram mantidas separadas para não misturar seus
diagnósticos com as substituições web anteriores. O fechamento consolidado,
com 15/15 contratos H2, auditoria do WAR, dependências, segurança e rollback,
está em [`Evidência CP-3G`](evidence/CP-3G.md).

## Atividade 3.33: descoberta por ServletContainerInitializer

Depois da migração para Jakarta EE 11, Reflections deixa de ser uma
dependência ativa. O mecanismo padrão Servlet `ServletContainerInitializer`
usa `@HandlesTypes(Validator.class)` para entregar ao projeto as classes
anotadas. A fachada `ValidatorDiscovery` mantém a regra já comprovada no
gate Java 17: descarta interfaces, classes abstratas e tipos que não
implementam `PedidoImportValidator`, exige construtores padrão, rejeita
identificadores duplicados e ordena por `order()` e nome completo.

A implementação do SCI, a annotation, o contrato, a fachada e o descritor de
serviço são empacotados em
`WEB-INF/lib/wildfly-migration-validator-sci.jar`. Os validators concretos
permanecem em `WEB-INF/classes` ou em JARs aprovados da aplicação. O registro
é armazenado no `ServletContext` do módulo web, sem dependência de API
exclusiva do WildFly e sem manter um cadastro manual de classes.

O smoke do WildFly 41 exige os marcadores de inicialização do SCI e da ordem
funcional no `server.log`; a auditoria estrutural verifica o conteúdo do JAR,
o descritor `META-INF/services/jakarta.servlet.ServletContainerInitializer`,
a ausência de Reflections e a ausência de cópias da infraestrutura em
`WEB-INF/classes`. O procedimento completo está em
[`CP-3G-servlet-container-initializer.md`](../migration/steps/CP-3G-servlet-container-initializer.md).

## Atividade 3.34: logging final

A ponte `log4j-over-slf4j` foi removida depois que os imports da aplicação
passaram a usar diretamente `org.slf4j`. O MyBatis define
`<setting name="logImpl" value="SLF4J"/>`, eliminando a autodetecção baseada no
classloader. A API SLF4J fica em `provided` e é fornecida pelo módulo do
WildFly 41; o WAR não contém ponte, API duplicada ou backend concorrente.

Os perfis H2 e Oracle configuram a categoria de persistência em `TRACE` e
mantêm o `correlationId` no padrão do servidor. Depois dos contratos, o smoke
tenta inserir um pedido com número duplicado; a transação sofre rollback e a
requisição deve falhar com HTTP 503. A auditoria confirma no `server.log` as categorias
`PedidoMapper`/`AnexoMapper`, o evento `legacy_order persistence_failure` e a
exceção completa, sem expor credenciais.

O procedimento detalhado está em
[`CP-3G-slf4j-mybatis.md`](../migration/steps/CP-3G-slf4j-mybatis.md).

## Rollback

O rollback do checkpoint retorna ao estado integrado do CP-3F e ao WAR Jakarta
anterior. Não restaura Tiles, Commons FileUpload, Reflections ou a ponte de
logging no código moderno, não altera o schema Oracle e não adiciona APIs
`javax` ao WAR Jakarta. O alvo e a verificação estão em
[`rollback.properties`](../migration/evidence/CP-3G/rollback.properties).
