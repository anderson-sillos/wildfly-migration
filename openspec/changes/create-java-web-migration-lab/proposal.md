## Why

A migração direta de uma aplicação Java 7/WildFly 9 para Java 25/WildFly 41 combina mudanças de linguagem, servidor, namespace `javax` para `jakarta`, bibliotecas abandonadas e integração com Oracle 19c. Um laboratório baseado na evolução de uma única aplicação e em entregas pequenas é necessário para ensinar um roteiro repetível sobre uma aplicação real, evitando acumular muitas mudanças antes de obter uma versão minimamente validável, versionada e reversível.

## What Changes

- Criar uma única aplicação web representativa e evoluí-la progressivamente, sem manter implementações legada e moderna em árvores de código independentes.
- Preservar cada estado reproduzível por tag/checkpoint Git, artefato WAR, manifesto de dependências e resultado dos testes de contrato.
- Dividir cada fase e gate em checkpoints parciais com no máximo quatro tarefas de implementação, uma validação mínima explícita e uma entrega própria no GitHub.
- Iniciar o trabalho por um checkpoint de bootstrap que configure o repositório Git/GitHub, o fluxo de branches e pull requests, as verificações obrigatórias e a documentação de instalação e configuração do ambiente.
- Exigir que cada checkpoint parcial seja reproduzível a partir de um checkout limpo, produza evidências proporcionais ao que já existe e seja integrado ao branch principal por um commit de entrega identificável.
- Organizar a migração em exatamente três fases públicas:
  1. baseline legado em Java 7u80 e WildFly 9.0.2;
  2. modernização máxima com baixo impacto em Java 8 e WildFly 26.1.3, mantendo EE 8 e `javax.*`;
  3. destino final em Java 25, WildFly 41 e Jakarta EE 11.
- Fixar Maven 3.8.9 como ferramenta do build legado por ser a última versão
  disponível compatível com Java 7, mantendo-a até a atualização explícita para
  Maven 3.9.16 no `CP-2C`.
- Adicionar fluxos funcionais de pedidos, sessão, filtros, listener, upload, acesso a dados via MyBatis/JNDI, páginas JSP, tag library customizada e processamento XML.
- Congelar o comportamento funcional no baseline e executar o mesmo contrato após cada fase.
- Executar a fase 3 por três gates técnicos internos e sequenciais, sem apresentá-los como fases públicas ou destinos independentes de produção:
  1. Java 17 no WildFly 26.1.3 para atualizar bibliotecas compatíveis com EE 8/`javax` e remover APIs duplicadas;
  2. Java 21 no WildFly 41 para migrar a aplicação para Jakarta EE 11 e aplicar as substituições arquiteturais;
  3. Java 25 no WildFly 41 para qualificação e fechamento do destino final.
- Na fase 3, substituir Log4j 1 e qualquer ponte temporária, Apache Tiles, Commons FileUpload e Reflections pelas soluções finais compatíveis com Jakarta EE 11.
- Na fase 3, confirmar e, quando necessário, ajustar MyBatis, Oracle JDBC, XMLBeans e dom4j para as versões finais aprovadas, provisionando o driver Oracle no WildFly, fora do WAR.
- Usar no destino final somente uma distribuição OpenJDK e a distribuição comunitária open source do WildFly, com versões fixadas, origem, licença e checksums registrados.
- Reproduzir incompatibilidades tentando executar o checkpoint anterior no runtime seguinte, usando fixtures artificiais apenas quando a falha não puder ser reproduzida naturalmente.
- Documentar cada fase e falha com pré-condições, sintomas, causa-raiz, correção, verificação, checkpoint e rollback.
- Validar o conteúdo efetivo do WAR em cada checkpoint e impedir o empacotamento de APIs fornecidas pelo servidor no destino final.
- **BREAKING** Na fase 3, migrar imports e contratos de `javax.servlet.*`, `javax.servlet.jsp.*`, `javax.servlet.jsp.tagext.*`, `javax.servlet.jsp.jstl.*` e `javax.el.*` para seus equivalentes `jakarta.*`.
- **BREAKING** Na fase 3, substituir layouts Tiles por JSP tag files/includes e substituir upload Commons FileUpload pelo multipart nativo de Servlet.

## Capabilities

### New Capabilities

- `legacy-webapp-baseline`: primeiro checkpoint da aplicação única, executável no ambiente legado e acompanhado de contrato funcional, inventário e artefato imutável.
- `modern-jakarta-webapp`: estado final da mesma aplicação após a terceira fase, executável no WildFly 41/Jakarta EE 11 e sem dependências descontinuadas.
- `migration-compatibility-lab`: progressão reproduzível pelos três checkpoints públicos, gates técnicos e checkpoints parciais entregues pelo GitHub, incluindo incompatibilidades, diagnósticos, evidências e rollback.
- `wildfly-oracle-runtime`: provisionamento reproduzível dos runtimes das três fases e dos gates internos, incluindo documentação de pré-requisitos, diagnóstico do ambiente, drivers JDBC, datasources JNDI e conectividade com Oracle Database 19c.

### Modified Capabilities

Nenhuma. O projeto ainda não possui especificações de capacidades existentes.

## Impact

- Uma única árvore Maven `app/`, modificada fase a fase, além de testes de contrato, runtimes, documentação e evidências.
- Repositório GitHub com branch principal protegido, branches de checkpoint, pull requests, verificações automatizadas e convenção de commits de entrega.
- Documentação inicial de instalação dos JDKs, Maven, WildFly, Git, ferramentas auxiliares e acesso ao Oracle, acompanhada de configuração segura e diagnóstico executável do ambiente.
- Três checkpoints Git verdes: `migration/01-legacy-baseline`, `migration/02-java8-wildfly26` e `migration/03-final`.
- Checkpoints parciais identificados por `CP-<fase><letra>`, preservados por commits de entrega no branch principal sem criar fases ou tags públicas adicionais.
- Configurações para Java 7, Java 8, Java 17, Java 21 e Java 25; Java 17 e Java 21 são gates internos da fase final, Maven 3.8.9 executa o build legado e Maven 3.9.16 passa a ser usado no `CP-2C`, depois da saída do Java 7.
- WildFly 9.0.2 no baseline, WildFly 26.1.3 como ponte EE 8/`javax` e WildFly 41.0.0.Final como destino.
- OpenJDK 25 e WildFly comunitário no destino, sem dependência de Oracle JDK, JBoss EAP ou outra distribuição proprietária do runtime.
- Jakarta EE Web Profile 11 no escopo `provided` somente na fase final, substituindo as APIs Servlet, JSP e JSTL antigas.
- Oracle Database 19c e `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0`.
- Gates internos para modernizar MyBatis, logging, upload, Tiles, Reflections, XMLBeans, dom4j e APIs XML antes e durante a transição Jakarta.
- Scripts, dados de teste, documentação, tags e verificações do conteúdo do WAR em cada fase.
