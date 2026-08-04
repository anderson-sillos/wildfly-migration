# Codex handoff

Atualizado em 04/08/2026 após a conclusão da atividade 3.36. A branch
incremental do CP-3H contém o gate XML e deve abrir a PR antes da atividade
3.37.

Este documento preserva o contexto operacional para a próxima sessão. Ele não
substitui o OpenSpec, os runbooks ou as evidências e não contém credenciais,
URLs Oracle, endereços internos nem valores do `.env`.

## Estado de retomada

- Repositório: `anderson-sillos/wildfly-migration`.
- Mudança OpenSpec: `create-java-web-migration-lab`.
- Branch atual: `checkpoint/cp-3h-entry`; o CP-3G está integrado no commit
  `a46c56a0c4a47b1fdcaca78b0ea7bd6d5e3a5bbe`.
- PR incremental do CP-3G: #25, `feat(CP-3G): replace Reflections with Servlet SCI`,
  encerrada por squash com a mensagem `checkpoint(CP-3G): replace legacy web libraries`.
- CP-3F: integrado pela PR #24 no commit `2e8df53b209db963e9a27026d9aca9124aa0ce37`.
- Progresso OpenSpec: 91 de 110 tarefas concluídas.
- Atividades CP-3B concluídas: 3.6, 3.7, 3.8, 3.9 e 3.10.
- Atividades CP-3G concluídas: 3.31, remoção do Tiles; 3.32, multipart Servlet;
  3.33, descoberta por `ServletContainerInitializer`; 3.34, logging final;
  3.35, fechamento do checkpoint.
- Próxima atividade OpenSpec: 3.37, provisionar o driver Oracle no WildFly 41.
  Ela ainda não foi iniciada.

## Decisões permanentes

- Uma única árvore Maven em `app/` evolui entre as fases; não existem
  `legacy-app` nem `modern-app`.
- A fase 1 usa Java 7u80/WildFly 9.0.2; a fase 2 usa Java 8/WildFly
  26.1.3/EE 8 `javax`; a fase 3 termina em OpenJDK 25/WildFly 41
  comunitário/Jakarta EE 11, com gates internos Java 17 e Java 21.
- H2 em memória fornece somente `portable-ci`. A qualificação oficial
  `oracle-qualified` exige Oracle Database 19c RU 19.3.
- Os dois perfis usam datasource e pool gerenciados pelo WildFly em
  `java:/jdbc/MigrationDS`; os drivers ficam fora do WAR.
- `.env`, credenciais, drivers proprietários e arquivos de runtime locais não
  são versionados.
- Cada checkpoint usa branch, PR e checks; somente o fechamento recebe o
  commit squash identificável.

## CP-3B concluído até a atividade 3.10

### 3.6 — MyBatis

- MyBatis foi atualizado de 3.4.5 para 3.5.19.
- Mappers, aliases, type handlers, reflexão, commit e rollback passaram no H2
  e no Oracle.
- O Oracle também aprovou `TIMESTAMP(6)` e BLOB.
- Commit de implementação:
  `d5f8a08242d4cdd18595a97e010954f1ee29f2f3`.

### 3.7 — logging

- `log4j:log4j:1.2.14` e `log4j.properties` foram removidos.
- Imports `org.apache.log4j` permanecem provisoriamente sobre
  `log4j-over-slf4j` 1.7.36.
- O WildFly fornece SLF4J e JBoss LogManager; o WAR não inclui API SLF4J nem
  backend concorrente.
- Categoria, MDC e stack trace completo passaram nos dois bancos.
- `logImpl` permanece implícito e deve ser fixado como `SLF4J` na atividade
  3.34.
- Commit de implementação:
  `c9a4ee17b3548e57bd3c5cc499051e34eeebcf9c`.

### 3.8 — upload

- Commons FileUpload foi atualizado de 1.2.2 para 1.6.0.
- Commons IO foi atualizado de 1.3.2 para 2.19.0 e continua explícito no POM.
- O contrato `javax.servlet`, `ServletFileUpload`, `DiskFileItemFactory` e
  `FileItem` foi preservado; a troca por Servlet `Part` pertence à 3.32.
- H2 e Oracle aprovaram upload válido, nome normalizado, round-trip de
  conteúdo/metadados, limites de 512 KiB por arquivo e 576 KiB por requisição
  e limpeza de temporários `upload_*`.
- Ambos reproduziram o WAR SHA-256
  `b199837b374d44cc84df1dcadbdfdf3ff53351201305c70828b9b2cc602fa3ff`.
- Commit de implementação:
  `64b5962e23a7d5dcb740c3a8d50a6ac172c8878f`.
- Commit de evidências: `beabe1b`.
- Rollback isolado da 3.8: retornar ao commit verde
  `e73f3184917984062d9ce8037d75236631399d99`.

### 3.32 — multipart Jakarta

- Commons FileUpload e Commons IO foram removidos do WAR Jakarta.
- `UploadServlet` e `XmlImportServlet` usam `@MultipartConfig` e `Part`, com
  limites, basename normalizado, leitura limitada e limpeza explícita.
- H2 e Oracle no WildFly 41 aprovaram os 15 cenários HTTP; evidências
  versionadas estão em `migration/evidence/CP-3G/upload-*.json` e usam
  `workingTree=false`.
- O CP-3F foi integrado no commit `2e8df53`; a atividade 3.33 está registrada
  no commit `671509d` e aguarda integração por PR.

### 3.33 — ServletContainerInitializer

- Reflections 0.10.2 foi removido do POM e da árvore ativa.
- `ValidatorServletContainerInitializer` usa `@HandlesTypes(Validator.class)`;
  `ValidatorDiscovery` filtra, instancia e ordena os validadores no
  `ServletContext`.
- A infraestrutura foi empacotada em
  `WEB-INF/lib/wildfly-migration-validator-sci.jar`, com o descritor
  `META-INF/services/jakarta.servlet.ServletContainerInitializer`; os três
  validators concretos permanecem em `WEB-INF/classes`.
- O smoke H2 no WildFly 41 aprovou os 15 cenários HTTP e registrou
  `validator_sci_discovery` e a ordem
  `numero-formato,valor-monetario,status-inicial`.
- Evidências: `migration/evidence/CP-3G/discovery-ci-h2.json`,
  `migration/evidence/CP-3G/logging-ci-h2.json` e
  `docs/evidence/CP-3G.md`.
- Commit de implementação: `671509d5e4e90f25fe7a1bb8f1ea28cbb8e23c50`.

### 3.34 — logging final SLF4J/MyBatis

- Os imports ativos foram migrados de Log4j 1 para `org.slf4j`; a ponte
  `log4j-over-slf4j` foi removida do POM e do WAR.
- `mybatis-config.xml` fixa `logImpl=SLF4J`; o WildFly 41 fornece a API SLF4J
  2.0.18 e o backend JBoss LogManager.
- H2/WildFly 41 executou os 15 contratos, registrou as categorias dos mappers
  e reproduziu a exceção de número duplicado com HTTP 503 e stack trace completo.
- Evidência: `migration/evidence/CP-3G/logging-ci-h2.json`; validação estática:
  `scripts/validate-cp-3g-logging.sh`.
- Commit de implementação: `68aa97d5702666ff5c76c440acab555af9bb8fb1`.

### 3.35 — fechamento do CP-3G

- O gate portátil executa 15/15 contratos no H2 e valida layout JSP, multipart
  Servlet, descoberta SCI, logging SLF4J/MyBatis, conteúdo do WAR,
  dependências e segurança.
- O fechamento e o rollback estão em `docs/evidence/CP-3G.md` e em
  `migration/evidence/CP-3G/{closure,rollback}.properties`.
- A evidência Oracle existente da atividade 3.32 continua limitada ao upload e
  importação XML; não foi tratada como qualificação Oracle completa do CP-3G.
- Validação: `scripts/validate-cp-3g-closure.sh`; PR #25 com
  `repository-baseline` e `portable-ci` verdes, integrada no squash
  `a46c56a0c4a47b1fdcaca78b0ea7bd6d5e3a5bbe`.

### 3.36 — XML moderno e seguro

- O POM mantém MyBatis `3.5.19`, XMLBeans `5.3.0` e dom4j `2.2.0`.
- O gate `scripts/validate-cp-3h-xml.sh` recompila o perfil Jakarta/Java 21,
  regenera `wildflyMigrationPedido1` e valida fixture legítima, XSD,
  namespace, round-trip, XXE e expansão de entidades.
- Evidência: `migration/evidence/CP-3H/xml-ci-h2.json`; resultado `passed`,
  WAR SHA-256 `83c60d4b509b8bfea3c869c6e2f7f4ecf2b49129cd2e61f292d06315251dde81`.

### 3.9 — descoberta de validadores

- Reflections foi atualizado de 0.9.10 para 0.10.2.
- Os três validadores concretos usam `@Validator`, e a ponte executa
  `getTypesAnnotatedWith(Validator.class)` com scanners e TCCL explícitos.
- H2 e Oracle observaram `org.jboss.modules.ModuleClassLoader`, o mesmo
  conjunto de três classes e a ordem
  `numero-formato,valor-monetario,status-inicial`.
- Guava 15 e FindBugs annotations 2.0.1 saíram do WAR; Reflections passou a
  trazer Javassist 3.28.0-GA e JSR-305 3.0.2. A API SLF4J transitiva foi
  excluída porque o WildFly já a fornece.
- Ambos reproduziram o WAR SHA-256
  `d3866778808f442b02691e1739ca7f0e8c1e6ec1c9dea7d99e72c9505362b5b5`.
- Commit de implementação:
  `14b9fbf23757c6cb721a4d9a809569d1b5c71b6b`.
- Rollback isolado da 3.9: retornar ao commit verde
  `28789b65964b6daf79082179893687140b84493b`.

### 3.10 — fechamento do checkpoint

- Os 14 contratos e a auditoria final passaram nos perfis H2 e Oracle.
- O CI remoto obrigatório passou no run `30650580350`.
- O WAR final tem SHA-256
  `d3866778808f442b02691e1739ca7f0e8c1e6ec1c9dea7d99e72c9505362b5b5` e 19
  bibliotecas.
- A evidência de fechamento está em
  `migration/evidence/CP-3B/closure.properties`.
- O rollback verificado aponta para `28789b65964b6daf79082179893687140b84493b`.
- Commit integrado: `checkpoint(CP-3B): modernize core dependencies`.

As conclusões explicativas estão em `docs/evidence/CP-3B.md`; os relatórios
sanitizados ficam em `migration/evidence/CP-3B/`.

## CP-3C — atividade 3.11 concluída

- XMLBeans foi atualizado de 2.3.0 para 5.3.0.
- O plugin Maven regenera os tipos em cada build a partir de
  `app/src/main/resources/xsd/pedido-importacao-v1.xsd`; o pacote gerado é
  `wildflyMigrationPedido1` e os fontes em `target/` não são versionados.
- O parser usa `PedidoDocument.Factory.parse` e `validate`, preservando as
  proteções contra DTD e entidades externas; dom4j 1.6.1 permanece para a
  atividade 3.12.
- O WAR contém `xmlbeans-5.3.0.jar` e `log4j-api-2.24.2.jar`, não contém
  `log4j-core` e não recebe mais `stax-api` como transitiva.
- A sonda aprovou fixture válida, rejeição por schema, namespace e
  `parse → xmlText → parse`; resultado sanitizado em
  `migration/evidence/CP-3C/xmlbeans-ci-h2.json`.
- WAR reproduzido com 19 bibliotecas, bytecode Java 17 e SHA-256
  `9434ac0841a0af52c5cf53e3f5a4c2a345c5cc8ed47b357ec034036bf4f10de0`.
- Detalhes e fontes oficiais: `docs/cp-3c-xmlbeans.md` e
  `migration/steps/CP-3C-xmlbeans-5.3.0.md`.

## CP-3C — atividade 3.12 concluída

- A coordenada foi alterada de `dom4j:dom4j:1.6.1` para
  `org.dom4j:dom4j:2.2.0`; nenhuma transitiva opcional foi adicionada ao WAR.
- O parser continua usando XMLReader namespace-aware com processamento seguro,
  DTD/entidades externas bloqueadas e `EntityResolver` de rejeição.
- Documento legítimo, XXE e expansão de entidades foram validados pela sonda
  `scripts/validate-cp-3c-dom4j.sh`.
- WAR reproduzido com 19 bibliotecas e SHA-256
  `6a5d3ba33b6bd1541d7a7aa59962daa5d719a48d973fd8062f800082094b59b3`.
- Detalhes: `docs/cp-3c-dom4j.md` e
  `migration/steps/CP-3C-dom4j-2.2.0.md`.

## Validações aprovadas

- `repository-baseline` local: aprovado.
- `doctor CP-3B/ci-h2 --non-interactive`: aprovado sem falha ou aviso.
- Build Java 17/Maven 3.9.16: 19 bibliotecas, bytecode major 61.
- Qualificação H2 2.4.240: aprovada como `portable-ci`.
- Qualificação Oracle 19c RU 19.3: aprovada como `oracle-qualified` e dados
  `LAB-SMOKE-*` removidos.
- H2 e Oracle: os mesmos 14 contratos HTTP, commit-fonte e WAR.
- GitHub Actions
  [run 30640741212](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30640741212):
  `repository-baseline` aprovado em 11s e `portable-ci` completo aprovado em
  59s.

Essa execução remota encerra a comprovação do comportamento do CI. Não repetir
auditorias históricas em cada atividade. Nos próximos PRs, acompanhar somente
os checks obrigatórios do SHA atual; consultar histórico de runs ou caches
apenas diante de falha, comportamento inesperado ou mudança no workflow/cache.

## Observação sobre o ambiente Codex

O WildFly precisa consultar interfaces de rede e abrir portas em loopback. Em
sandbox com rede restrita, o boot falha com
`java.net.SocketException: Operation not permitted (Socket creation failed)`.
Isso é uma restrição do executor, não incompatibilidade da aplicação. As
sondas de runtime devem receber permissão de loopback; validações estáticas e
o build podem executar no sandbox.

## Próxima ação

Após integrar a entrega da 3.12, retomar pela atividade 3.13 sem refazer a
auditoria histórica de CI já aprovada:

```bash
git status --short --branch
openspec status --change create-java-web-migration-lab --json
openspec instructions apply --change create-java-web-migration-lab --json
./scripts/doctor.sh CP-3B --profile ci-h2 --env .env --non-interactive
./scripts/validate-cp-3c-dom4j.sh --env .env --skip-build
```

A troca de Reflections por `ServletContainerInitializer` em JAR separado
continua reservada às subtarefas da atividade 3.33.
