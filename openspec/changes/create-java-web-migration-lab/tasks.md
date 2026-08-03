## 1. Baseline legado

### Checkpoint CP-1A — Repositório GitHub e ambiente

- [x] 1.1 Definir proprietário, nome, visibilidade e branch principal, inicializar o repositório Git, criar o repositório GitHub e configurar o remote sem versionar credenciais.
- [x] 1.2 Configurar branches `checkpoint/*`, pull requests, squash merge, verificações obrigatórias e proteção do branch principal compatível com as permissões disponíveis, além de templates de PR e contribuição.
- [x] 1.3 Documentar instalação ou fornecimento de Git, ferramenta de acesso ao GitHub, runtime de containers, Java 7/8/17/21/25, Maven 3.9.16, WildFly 9/26/41 e acesso ao Oracle 19c, distinguindo distribuições open source, proprietárias e não redistribuíveis.
- [x] 1.4 Criar configuração segura de exemplo, ignores e o diagnóstico `doctor` para versões, checksums, variáveis, portas e pré-requisitos exigidos pelo checkpoint selecionado.
- [x] 1.5 Encerrar `CP-1A`: validar um clone limpo seguindo somente a documentação, registrar evidências e rollback, abrir o PR e integrá-lo pelo commit `checkpoint(CP-1A): bootstrap repository and environment`.

### Checkpoint CP-1B — Estrutura e runtime legado

- [x] 1.6 Criar a única árvore Maven `app/` e as áreas `contract-tests/`, `runtime/`, `migration/steps/` e `docs/`, preservando uma única linha evolutiva.
- [x] 1.7 Definir a forma isolada de fornecer Java 7u80 e WildFly 9.0.2 sem versionar binários proprietários e fixar checksums e origem.
- [x] 1.8 Fixar Maven 3.8.9 como ferramenta do build legado e adicionar verificações executáveis para Java 7u80, Maven 3.8.9 e WildFly 9.0.2 que falhem rapidamente e registrem versões, origem e checksums efetivamente usados.
- [x] 1.9 Definir o modelo mínimo de pedido, anexo e preferência de sessão, scripts SQL idempotentes para Oracle 19c, XSD e exemplos XML válidos e maliciosos.
- [x] 1.10 Encerrar `CP-1B`: validar estrutura, documentação, `doctor`, checksums e scripts estáticos, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-1B): scaffold legacy runtime`.

### Checkpoint CP-1C — WAR e dependências legadas

- [x] 1.11 Configurar com Maven 3.8.9 o WAR para Java 7 com `javax.servlet:servlet-api:2.4`, `javax.servlet:jsp-api:2.0` e `javax.servlet.jsp.jstl:jstl-api:1.2` em `provided`.
- [x] 1.12 Declarar MyBatis 3.4.5, Log4j 1.2.14, Commons FileUpload 1.2.2, Reflections 0.9.10, Tiles 2.1.4, XMLBeans 2.3.0, dom4j 1.6.1, `xml-apis` 1.3.02 e Geronimo StAX 1.0.
- [x] 1.13 Configurar o fornecimento externo do `ojdbc7` para o laboratório, sem versionar o binário, e relacioná-lo ao datasource JNDI legado.
- [x] 1.14 Implementar a auditoria inicial da árvore Maven, escopos, conteúdo previsto de `WEB-INF/lib` e ausência de JARs manuais.
- [x] 1.15 Encerrar `CP-1C`: compilar e empacotar o WAR mínimo quando os binários exigidos estiverem disponíveis, validar a auditoria, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-1C): build legacy war skeleton`.

### Checkpoint CP-1D — Fundação CI H2 e qualificação Oracle

- [x] 1.16 Revisar o impacto do H2 sobre as entregas `1.3`, `1.4`, `1.9` e `1.14`, selecionar e fixar uma distribuição Java 7 redistribuível e uma versão H2 compatível e atualizar documentação e manifestos com versão, origem, licença, checksum, condição EOL e distinção para a reprodução exata com Oracle JDK 7u80.
- [x] 1.17 Estender `.env.example`, ignores, `doctor` e auditoria do WAR para os perfis `ci-h2` e `oracle`, exigindo somente os pré-requisitos do perfil selecionado e rejeitando H2, `ojdbc` ou segredos dentro do WAR ou do controle de versão.
- [x] 1.18 Criar scripts H2 próprios de schema, massa e limpeza semanticamente equivalentes aos scripts Oracle canônicos, automatizar sua validação estática e registrar diferenças de tipos, constraints, sequences, timestamps e LOBs.
- [x] 1.19 Configurar no WildFly 9 os perfis `ci-h2` e `oracle` sob `java:/jdbc/MigrationDS`, impedir console/listener H2, testar os dois datasources e preparar o workflow portátil sem expor a rede interna.
- [x] 1.20 Encerrar `CP-1D`: executar `doctor`, auditorias, scripts e smoke de datasource `portable-ci` no CI hospedado e `oracle-qualified` na rede interna, registrar evidências sanitizadas e rollback e integrar o PR pelo commit `checkpoint(CP-1D): establish portable persistence foundation`.

### Checkpoint CP-1E — Fluxo web e persistência

- [x] 1.21 Implementar domínio, mappers XML, aliases, type handlers e transações MyBatis por datasource JNDI, mantendo SQL comum e isolando por `databaseIdProvider` somente as diferenças H2/Oracle inevitáveis.
- [x] 1.22 Implementar Servlets de pedidos, filtro de encoding e correlação, listener de inicialização e preferência em `HttpSession`.
- [x] 1.23 Implementar JSPs/JSTL com layout Tiles e o TLD 2.0 com handler baseado em `javax.servlet.jsp.tagext`.
- [x] 1.24 Criar smoke tests para inicialização, listagem, criação, consulta e sessão nos perfis H2 e Oracle.
- [x] 1.25 Encerrar `CP-1E`: executar build, implantação e smoke tests `portable-ci` no CI hospedado e `oracle-qualified` na rede interna, registrar commit, checksum do WAR, evidências sanitizadas e rollback e integrar o PR pelo commit `checkpoint(CP-1E): deliver legacy web flow`.

### Checkpoint CP-1F — Integrações e contratos

- [x] 1.26 Implementar upload por Commons FileUpload 1.2.2 com limites e metadados comparáveis.
- [x] 1.27 Implementar importação XML por XMLBeans 2.3.0 e dom4j 1.6.1, incluindo validação por XSD.
- [x] 1.28 Usar Reflections para descoberta de validadores e Log4j 1 para os logs do fluxo legado.
- [x] 1.29 Implementar a suíte HTTP externa para listagem, criação, consulta, sessão, upload e importação XML sem importar classes do WAR e reutilizar os mesmos casos nos perfis H2 e Oracle.
- [x] 1.30 Encerrar `CP-1F`: executar contratos e cenários negativos em H2 no CI e Oracle na rede interna, registrar resultados separados, evidências sanitizadas e rollback e integrar o PR pelo commit `checkpoint(CP-1F): add legacy integrations and contracts`.

### Checkpoint CP-1G — Baseline completo

- [x] 1.31 Congelar resultados normalizados dos contratos comuns, o estado persistido Oracle de referência e as diferenças H2 documentadas que servirão de comparação para as fases seguintes.
- [x] 1.32 Gerar manifesto com árvore Maven, versões, origem e licença dos componentes e da infraestrutura de teste, conteúdo de `WEB-INF/lib` e checksum do WAR.
- [x] 1.33 Implantar o WAR no WildFly 9.0.2 isolado e aprovar `portable-ci`, `oracle-qualified`, contratos, persistência, auditorias, segredos e portas.
- [x] 1.34 Documentar preparação, execução, verificação, limpeza e rollback do baseline a partir de checkout limpo.
- [x] 1.35 Encerrar `CP-1G`: validar todas as evidências H2 e Oracle da fase, integrar o PR pelo commit `checkpoint(CP-1G): complete legacy baseline` e criar a tag `migration/01-legacy-baseline`.

## 2. Modernização máxima com baixo impacto

### Checkpoint CP-2A — Java 8 no WildFly 9

- [x] 2.1 Materializar `migration/01-legacy-baseline` e tentar executar a aplicação com Java 8 no WildFly 9 antes de qualquer correção.
- [x] 2.2 Capturar incompatibilidades causadas pela mudança Java 7 para Java 8 com sintoma, causa e evidência.
- [x] 2.3 Ajustar somente o necessário para compilar e executar com Java 8 no WildFly 9, mantendo dependências e namespace `javax`.
- [x] 2.4 Executar contratos, persistência H2/Oracle e auditoria do WAR e documentar o rollback para o baseline.
- [x] 2.5 Encerrar `CP-2A`: validar Java 8/WildFly 9, registrar evidências e integrar o PR pelo commit `checkpoint(CP-2A): run legacy application on Java 8`.

### Checkpoint CP-2B — Migração para WildFly 26

- [x] 2.6 Tentar implantar no WildFly 26.1.3 com Java 8 o mesmo WAR aprovado em `CP-2A` antes de alterar configuração ou código.
- [x] 2.7 Capturar incompatibilidades de configuração, datasource, segurança, logging e classloader entre WildFly 9 e 26.1.3.
- [x] 2.8 Provisionar WildFly 26.1.3/Java 8 e migrar sua configuração sem alterar o namespace `javax.*`.
- [x] 2.9 Configurar no WildFly 26 os perfis H2 e Oracle, seus drivers, o mesmo JNDI e verificações de saúde sem alterar o contrato funcional do schema.
- [x] 2.10 Encerrar `CP-2B`: validar implantação e smoke tests no WildFly 26, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-2B): migrate runtime to WildFly 26`.

### Checkpoint CP-2C — EE 8, Maven e datasource

- [x] 2.11 Alinhar as APIs do build a Jakarta EE 8 com pacotes `javax.*` e escopo `provided`, rejeitando APIs do contêiner em `WEB-INF/lib`.
- [x] 2.12 Atualizar a ferramenta de build de Maven 3.8.9 para Maven 3.9.16 e documentar a diferença entre a versão do Maven e `<modelVersion>4.0.0</modelVersion>`.
- [x] 2.13 Validar a paridade portátil em H2 e qualificar no Oracle o datasource, as transações MyBatis, timestamps e LOBs com o driver aprovado para Java 8.
- [x] 2.14 Atualizar `doctor`, CI H2, qualificação Oracle e auditoria do WAR para a combinação Java 8/WildFly 26/EE 8.
- [x] 2.15 Encerrar `CP-2C`: executar build, contratos H2 e Oracle e auditorias, registrar evidências separadas e rollback e integrar o PR pelo commit `checkpoint(CP-2C): align build with EE 8`.

### Checkpoint CP-2D — Fechamento da ponte

- [x] 2.16 Executar a suíte completa em H2 e Oracle e comparar respostas, estado persistido oficial e limitações portáteis com a fase 1.
- [x] 2.17 Gerar o manifesto da fase 2 com versões, dependências, WAR, runtime, checksums e limitações conhecidas.
- [x] 2.18 Documentar um roteiro equivalente para aplicação real, incluindo janela de transição, implantação blue/green, verificações e rollback.
- [x] 2.19 Reproduzir a fase 2 a partir de checkout limpo usando somente documentação e configuração externa segura.
- [x] 2.20 Encerrar `CP-2D`: aprovar as evidências `portable-ci` e `oracle-qualified`, integrar o PR pelo commit `checkpoint(CP-2D): complete low-impact modernization` e criar a tag `migration/02-java8-wildfly26`.

## 3. Destino final com gates técnicos internos

### Checkpoint CP-3A — Entrada no Java 17

- [x] 3.1 Materializar `migration/02-java8-wildfly26` e tentar executar a aplicação com Java 17 no WildFly 26.1.3 antes de atualizar bibliotecas.
- [x] 3.2 Capturar e corrigir somente incompatibilidades necessárias ao Java 17 e reexecutar os contratos antes de modernizar dependências.
- [x] 3.3 Produzir a matriz de cada dependência legada com versão candidata, suporte a Java 17, compatibilidade EE 8/`javax`, transitivas, impacto e decisão.
- [x] 3.4 Atualizar runtime, versão H2 de teste, documentação e `doctor` para a combinação Java 17/WildFly 26, preservando o perfil Oracle separado.
- [x] 3.5 Encerrar `CP-3A`: validar inicialização, contratos H2/Oracle e auditoria no Java 17, registrar evidências separadas e rollback e integrar o PR pelo commit `checkpoint(CP-3A): establish Java 17 runtime`.

### Checkpoint CP-3B — Dependências centrais

- [x] 3.6 Atualizar MyBatis para 3.5.19 e validar em H2 e Oracle os mappers, aliases, type handlers, reflexão e limites transacionais.
- [x] 3.7 Remover `log4j:log4j` e adotar logging mantido, usando ponte temporária da API 1.2 somente onde necessário no gate Java 17.
- [x] 3.8 Atualizar Commons FileUpload para a última linha 1.x aprovada compatível com `javax` e preservar provisoriamente o contrato de upload.
- [x] 3.9 Atualizar Reflections para 0.10.2 e validar descoberta, conjunto e ordem dos validadores no classloader do WildFly 26.
- [x] 3.10 Encerrar `CP-3B`: executar contratos e auditoria depois das atualizações, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-3B): modernize core dependencies`.

### Checkpoint CP-3C — XML e Oracle JDBC

- [x] 3.11 Atualizar XMLBeans para 5.3.0, regenerar os tipos a partir do XSD e validar serialização, namespaces e schema.
- [x] 3.12 Atualizar dom4j para 2.2.0 e configurar parsing seguro sem alterar documentos legítimos.
- [x] 3.13 Remover `xml-apis` e Geronimo StAX e comprovar o uso das APIs do módulo `java.xml`.
- [x] 3.14 Trocar `ojdbc7` por um driver mantido compatível com Java 17 e Oracle 19c, preservar o perfil H2 portátil e testar transações, timestamps e LOBs nos dois perfis com qualificação oficial no Oracle.
- [x] 3.15 Encerrar `CP-3C`: executar testes XML, H2 e Oracle, auditar dependências, registrar evidências separadas e rollback e integrar o PR pelo commit `checkpoint(CP-3C): modernize XML and JDBC`.

### Checkpoint CP-3D — Gate Java 17

- [x] 3.16 Manter Tiles e handlers TLD em `javax` somente como exceções temporárias documentadas, sem atualizar para outra versão descontinuada.
- [x] 3.17 Executar contratos H2 e Oracle e auditoria completos no Java 17/WildFly 26 e comparar com o baseline.
- [x] 3.18 Gerar manifesto do gate com dependências atualizadas, exceções adiadas, checksum do WAR e resultados.
- [x] 3.19 Documentar reprodução e rollback do gate para `migration/02-java8-wildfly26`.
- [x] 3.20 Encerrar `CP-3D`: aprovar evidências `portable-ci` e `oracle-qualified` do gate Java 17 sem criar fase ou tag pública e integrar o PR pelo commit `checkpoint(CP-3D): approve Java 17 gate`.

### Checkpoint CP-3E — Entrada no WildFly 41

- [ ] 3.21 Tentar implantar o WAR aprovado em `CP-3D` sem transformação no WildFly 41.0.0.Final com OpenJDK 21 antes de corrigir código ou descritores.
- [ ] 3.22 Capturar incompatibilidades de Java, servidor, namespace, datasource, segurança, logging, JSP/TLD e classloader.
- [ ] 3.23 Provisionar OpenJDK 21, WildFly 41 comunitário e uma versão H2 de teste compatível, todos com origem, licença, versão e checksum registrados.
- [ ] 3.24 Substituir as APIs EE 8 por `jakarta.platform:jakarta.jakartaee-web-api:11.0.0` em `provided`.
- [ ] 3.25 Encerrar `CP-3E`: validar o runtime, o diagnóstico e o primeiro build Jakarta, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-3E): enter WildFly 41 and Jakarta EE 11`.

### Checkpoint CP-3F — Namespace e descritores Jakarta

- [ ] 3.26 Migrar Servlets, filtros, listeners, sessão, tag handlers e EL de `javax.*` para `jakarta.*`, preservando `javax.sql`, `javax.naming` e `javax.xml`.
- [ ] 3.27 Atualizar `web.xml`, JSPs, JSTL e demais descritores para Jakarta EE 11 e URIs `jakarta.tags.*`.
- [ ] 3.28 Implantar primeiro o TLD histórico, capturar o comportamento e concluir o handler em `jakarta.servlet.jsp.tagext`.
- [ ] 3.29 Compilar, implantar e executar contratos H2 e Oracle de listagem, criação, consulta e sessão no Java 21/WildFly 41.
- [ ] 3.30 Encerrar `CP-3F`: validar ausência dos namespaces EE `javax` proibidos, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-3F): migrate Jakarta namespaces`.

### Checkpoint CP-3G — Substituições web

- [ ] 3.31 Substituir Tiles por JSP tag files ou includes sob `WEB-INF` e comprovar a equivalência do layout.
- [ ] 3.32 Substituir Commons FileUpload por `@MultipartConfig` e `jakarta.servlet.http.Part` com limites, normalização, validação e limpeza.
- [ ] 3.33 Substituir Reflections pelo mecanismo padrão Jakarta Servlet `ServletContainerInitializer` com `@HandlesTypes(Validator.class)`, fornecido em JAR interno de `WEB-INF/lib` com o registro `META-INF/services`, encapsulado por fachada própria e validado quanto a classes elegíveis, conjunto e ordem em `WEB-INF/classes` e `WEB-INF/lib` no Java 21/WildFly 41.
- [ ] 3.34 Remover a ponte temporária de Log4j, definir explicitamente `logImpl=SLF4J` no MyBatis e integrar os logs ao mecanismo final do WildFly, comprovando no `server.log` as categorias dos mappers e exceções completas sem empacotar backend concorrente no WAR.
- [ ] 3.35 Encerrar `CP-3G`: executar contratos web, validar descoberta, fachada, conteúdo e registro do JAR interno do SCI, executar auditoria de dependências e segurança, registrar evidências e rollback e integrar o PR pelo commit `checkpoint(CP-3G): replace legacy web libraries`.

### Checkpoint CP-3H — Oracle e auditoria final

- [ ] 3.36 Fixar MyBatis 3.5.19, XMLBeans 5.3.0 e dom4j 2.2.0 e reexecutar geração e testes XML seguros.
- [ ] 3.37 Provisionar `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` no WildFly, preservar o perfil H2 em memória e publicar `java:/jdbc/MigrationDS` nos dois perfis sem empacotar drivers no WAR.
- [ ] 3.38 Executar a suíte Oracle 19c e registrar versão completa, Release Update, driver, JVM e WildFly observados.
- [ ] 3.39 Implementar a auditoria que rejeite APIs do contêiner, Log4j 1/ponte, Tiles, Commons FileUpload 1, Reflections, bibliotecas externas de scanning, `xml-apis`, Geronimo StAX e `ojdbc7` e valide o JAR interno e o descritor de serviço do SCI definidos na atividade `3.33`.
- [ ] 3.40 Encerrar `CP-3H`: validar H2, Oracle, XML, dependências e WAR, registrar evidências separadas e rollback e integrar o PR pelo commit `checkpoint(CP-3H): finalize Oracle and packaging`.

### Checkpoint CP-3I — Gate Java 21

- [ ] 3.41 Testar no H2 a semântica portátil e qualificar no Oracle rollback, sequence, paginação, timestamps/timezone, CLOB e BLOB com `ojdbc17`.
- [ ] 3.42 Executar contratos completos H2 e Oracle no Java 21/WildFly 41 e comparar respostas, estado persistido e limitações com o baseline.
- [ ] 3.43 Gerar manifesto do gate Java 21 com runtime, licenças, checksums, WAR, dependências e evidências.
- [ ] 3.44 Documentar reprodução, implantação equivalente em produção e rollback para o gate Java 17.
- [ ] 3.45 Encerrar `CP-3I`: aprovar evidências `portable-ci` e `oracle-qualified` do gate Java 21 sem criar tag pública e integrar o PR pelo commit `checkpoint(CP-3I): approve Java 21 Jakarta gate`.

### Checkpoint CP-3J — OpenJDK 25

- [ ] 3.46 Verificar atualizações open source disponíveis, selecionar e fixar a distribuição OpenJDK 25, o WildFly 41 comunitário e o H2 de teste aprovados, registrando origem, licença e checksums e rejeitando Oracle JDK ou JBoss EAP.
- [ ] 3.47 Alterar somente a JVM do WildFly 41 de OpenJDK 21 para OpenJDK 25.
- [ ] 3.48 Capturar diferenças exclusivas do JDK 25 e aplicar o menor conjunto de correções sem alterar o contrato funcional.
- [ ] 3.49 Executar as trilhas H2 e Oracle no OpenJDK 25 e a qualificação adicional no OpenJDK 21, incluindo contratos, empacotamento, segredos, portas e proveniência open source.
- [ ] 3.50 Encerrar `CP-3J`: validar o destino OpenJDK/WildFly comunitário com evidências `portable-ci` e `oracle-qualified`, registrar rollback e integrar o PR pelo commit `checkpoint(CP-3J): qualify OpenJDK 25`.

### Checkpoint CP-3K — Destino final

- [ ] 3.51 Completar o catálogo de incompatibilidades com falhas naturais e fixtures opt-in somente onde a reprodução natural não for determinística.
- [ ] 3.52 Gerar relatório consolidado com as três fases, checkpoints parciais, gates, versões, estados `portable-ci` e `oracle-qualified`, exceções resolvidas e limitações.
- [ ] 3.53 Reproduzir o destino final a partir de checkout limpo usando documentação, `doctor`, OpenJDK, WildFly comunitário, H2 em memória e configuração Oracle externa.
- [ ] 3.54 Auditar histórico Git, rastreabilidade de PRs e commits, segredos, licenças, checksums, dependências, WAR e instruções de rollback.
- [ ] 3.55 Encerrar `CP-3K`: aprovar todas as evidências H2 e Oracle, integrar o PR pelo commit `checkpoint(CP-3K): complete final destination` e criar a tag `migration/03-final`.
