## Context

O projeto será um laboratório de migração, não uma conversão automática de uma base de código existente. Ele deverá representar os pontos de acoplamento observados na aplicação real: Java 7u80, WildFly 9.0.2, Servlet 2.4, JSP 2.0, JSTL 1.2, tag library customizada, Tiles, upload, MyBatis, Oracle 19c, processamento XML, descoberta de classes e Log4j 1.

Uma única árvore de código da aplicação será criada no estado legado e modificada progressivamente. O histórico, as tags Git, os WARs e os manifestos preservarão os estados anteriores, mantendo uma única linha evolutiva.

A progressão terá exatamente três fases públicas: baseline legado; modernização máxima com baixo impacto em Java 8/WildFly 26.1.3/EE 8 `javax`; e destino final em Java 25/WildFly 41/Jakarta EE 11. A fase final conterá gates técnicos em Java 17 e Java 21 para isolar riscos, mas somente o fim de cada fase pública receberá uma tag Git.

Maven 3.8.9 será fixado como a última versão disponível capaz de executar com Java 7 e será usado somente no caminho legado isolado. Ele permanecerá durante `CP-2A` e `CP-2B` para que a troca de JVM e servidor não seja misturada com a troca da ferramenta de build. Maven 3.9.16 será adotado explicitamente no `CP-2C`; Maven 4 permanecerá fora do caminho de produção enquanto não houver versão GA. O ambiente legado é deliberadamente inseguro e obsoleto. Sua reprodução exata com Oracle JDK 7u80 e Oracle 19c ocorrerá somente em ambiente controlado, enquanto o CI hospedado executará uma trilha complementar com uma distribuição Java 7 redistribuível aprovada e H2 em memória.

Não existem JARs versionados manualmente em `WEB-INF/lib`. Mesmo assim, o conteúdo do WAR de cada fase deverá ser auditado, pois dependências Maven sem escopo `provided` são copiadas para esse diretório durante o empacotamento.

## Goals / Non-Goals

**Goals:**

- Disponibilizar um fluxo funcional pequeno, porém realista, com pedidos, sessão, JSP, tag customizada, upload, XML, MyBatis e Oracle.
- Evoluir a mesma aplicação em três fases reproduzíveis, cada uma encerrada por um checkpoint verde.
- Preservar um contrato HTTP e funcional comum entre todos os checkpoints.
- Tornar reproduzíveis as principais falhas de uma migração `javax` para `jakarta` e de atualização do JDK.
- Demonstrar correções incrementais com evidência automatizada.
- Executar, a partir do `CP-1D`, em todo pull request aplicável uma validação funcional portátil, sem acesso à rede interna ou a credenciais Oracle.
- Distinguir evidência portátil obtida com H2 de qualificação oficial obtida com Oracle 19c.
- Produzir entregas parciais pequenas, minimamente validáveis e integradas ao GitHub sem acumular grandes lotes de tarefas.
- Permitir que uma pessoa prepare e diagnostique o ambiente a partir da documentação antes de implementar a aplicação.
- Garantir que o destino final dependa somente de distribuições open source de Java e WildFly.
- Separar APIs fornecidas pelo WildFly, bibliotecas empacotadas no WAR e componentes provisionados no servidor.
- Produzir documentação que possa ser reutilizada como roteiro na aplicação real.

**Non-Goals:**

- Migrar a aplicação real ou reproduzir todo o seu domínio.
- Manter duas implementações independentes da aplicação.
- Executar Java 7, WildFly 9, Log4j 1 ou bibliotecas vulneráveis em produção.
- Migrar JSP para uma tecnologia de frontend diferente.
- Substituir MyBatis por JPA ou outro framework de persistência.
- Atualizar o Oracle Database 19c.
- Tratar H2, seu modo Oracle ou outro banco alternativo como prova de compatibilidade com Oracle Database 19c.
- Avaliar carga, alta disponibilidade, cluster ou disaster recovery.
- Usar Maven 4 release candidate como ferramenta obrigatória.

## Decisions

### 1. Uma aplicação, três checkpoints públicos

O repositório terá uma única árvore `app/`, além de `contract-tests/`, `runtime/`, `migration/steps/` e `docs/`. O conteúdo de `app/` evoluirá na linha principal; cada fase aprovada será preservada por uma tag Git e por evidências verificáveis.

Os checkpoints serão:

| Fase | Checkpoint | Plataforma ao final |
|---|---|---|
| 1 | `migration/01-legacy-baseline` | Java 7u80, WildFly 9.0.2, APIs e dependências legadas |
| 2 | `migration/02-java8-wildfly26` | Java 8, WildFly 26.1.3, Jakarta EE 8 com pacotes `javax.*` |
| 3 | `migration/03-final` | Java 25, WildFly 41.0.0.Final, Jakarta EE 11 |

Git worktrees poderão materializar dois checkpoints lado a lado quando uma comparação exigir execução simultânea, sem duplicar ou manter duas bases de código.

Dentro da fase 3, os estados Java 17/WildFly 26 e Java 21/WildFly 41 serão gates técnicos verdes, com manifesto, contratos e rollback documentados. Eles poderão ser preservados por commits identificáveis e artefatos de evidência, mas não serão apresentados como novas fases públicas, tags de produção ou destinos permanentes.

Alternativas consideradas: manter implementações paralelas, o que demonstraria uma reescrita em vez de uma migração aplicável ao sistema real; e compilar toda a árvore com Java 25 usando apenas `source`/`target` 7, o que não reproduziria diferenças do runtime Java 7. Ambas foram descartadas.

### 2. Checkpoints parciais e fluxo de entrega no GitHub

As três fases públicas permanecerão inalteradas, mas sua implementação será particionada em checkpoints parciais identificados por `CP-<fase><letra>`. Um checkpoint parcial terá no máximo quatro tarefas de implementação e uma tarefa de encerramento. Se o escopo ultrapassar esse limite, ele será dividido antes do desenvolvimento.

Cada encerramento de checkpoint deverá:

1. executar o conjunto mínimo de build, testes, auditorias e diagnóstico de ambiente aplicável ao estado já implementado;
2. atualizar documentação, evidências e instrução de retorno ao último checkpoint verde;
3. partir de uma branch `checkpoint/<id>-<descricao>`;
4. abrir um pull request com as verificações automatizadas exigidas pelo branch principal;
5. produzir por squash merge um commit `checkpoint(<ID>): <entrega>` identificável no histórico.

As tags `migration/01-legacy-baseline`, `migration/02-java8-wildfly26` e `migration/03-final` continuarão reservadas ao encerramento das fases públicas. Checkpoints parciais e gates internos serão localizados pelos commits de entrega, sem criar novas fases ou tags públicas.

Quando uma decisão posterior ampliar um requisito já coberto por checkpoint integrado, o checkmark histórico não será removido nem seu texto será reescrito para sugerir que o trabalho novo já existia. Os deltas serão auditados e entregues no primeiro checkpoint pendente que antecede o código dependente. A adoção do H2 afeta documentação do ambiente (`1.3`), diagnóstico/configuração (`1.4`), scripts de banco (`1.9`) e auditoria do WAR (`1.14`); por isso, o novo `CP-1D` reconciliará esses quatro pontos antes da implementação do fluxo web.

O primeiro checkpoint, `CP-1A`, será concluído antes da criação da aplicação. Ele configurará o repositório GitHub, branch principal, proteção e verificações, convenções de branch/PR/commit, arquivos de contribuição e a documentação inicial. Essa documentação relacionará Git, ferramenta de acesso ao GitHub, runtime de containers, Java 7/8/17/21/25, Maven 3.9.16, WildFly 9/26/41 e acesso ao Oracle 19c; explicará o que pode ser instalado automaticamente, o que deve ser fornecido pelo usuário e como configurar valores sem versionar segredos ou binários proprietários. A decisão posterior de fixar Maven 3.8.9 para o legado será incorporada à documentação e ao diagnóstico no `CP-1B`, sem reabrir o checkpoint já entregue.

Um comando de diagnóstico, referido como `doctor`, validará ferramentas, versões, checksums, variáveis e conectividade disponíveis para o checkpoint selecionado. O checkpoint só será entregue quando um checkout limpo seguir a documentação e alcançar sua validação mínima. A trilha H2 aplicável deverá passar no CI hospedado; resultados Oracle poderão aparecer como “não executados” durante o desenvolvimento quando o ambiente interno estiver indisponível, mas checkpoints que qualificam persistência e as três tags públicas não serão encerrados sem a evidência `oracle-qualified` correspondente.

Os checkpoints planejados são:

| Fase | Checkpoints parciais |
|---|---|
| 1 | `CP-1A` repositório e ambiente; `CP-1B` estrutura e runtime legado; `CP-1C` WAR e dependências; `CP-1D` fundação H2/Oracle; `CP-1E` fluxo web/persistência; `CP-1F` integrações e contratos; `CP-1G` baseline completo |
| 2 | `CP-2A` Java 8/WildFly 9; `CP-2B` WildFly 26; `CP-2C` EE 8, Maven e datasource; `CP-2D` fechamento da ponte |
| 3 | `CP-3A` Java 17; `CP-3B` dependências centrais; `CP-3C` XML e Oracle JDBC; `CP-3D` gate Java 17; `CP-3E` entrada no WildFly 41; `CP-3F` namespace e descritores; `CP-3G` substituições web; `CP-3H` Oracle e auditoria; `CP-3I` gate Java 21; `CP-3J` Java 25; `CP-3K` destino final |

Alternativas consideradas: criar um único commit ao final de cada fase, o que concentraria muitas mudanças e tornaria o diagnóstico e o rollback pouco precisos; e criar uma tag para toda entrega parcial, o que confundiria checkpoints de engenharia com as três fases públicas. Ambas foram descartadas.

### 3. Domínio mínimo representativo

A aplicação será um cadastro de pedidos com:

- listagem, criação e consulta de pedidos;
- sessão HTTP para preferências do usuário;
- filtro de encoding e correlação de requisição;
- listener de inicialização;
- JSP/JSTL para renderização;
- layout Tiles no legado e JSP tag files/includes no moderno;
- tag customizada para apresentação de valor ou status;
- anexo multipart associado ao pedido;
- importação de pedido XML validada por schema;
- persistência MyBatis por datasource JNDI.

Esse conjunto é pequeno o suficiente para entendimento rápido, mas ativa todas as bibliotecas problemáticas do inventário.

### 4. Contrato funcional estável

Testes externos ao WAR chamarão o checkpoint ativo pela interface HTTP e compararão status, redirecionamentos, conteúdo normalizado e efeitos persistidos com a baseline congelada na fase 1. Diferenças cosméticas ou geradas pelo contêiner serão normalizadas; regras de negócio e resultados não serão.

A mesma suíte funcional será executada contra dois perfis de datasource:

1. `ci-h2`, obrigatório em cada pull request aplicável a partir do `CP-1D` e classificado como `portable-ci`;
2. `oracle`, executado em ambiente autorizado na rede interna e classificado como `oracle-qualified`.

O sucesso do perfil H2 comprovará o fluxo da aplicação, a integração JNDI/MyBatis e a semântica portátil selecionada, mas não comprovará o driver, o SQL, os LOBs, os timestamps, os códigos de erro ou o comportamento transacional específico do Oracle. A evidência de cada execução registrará perfil, commit, checksum do WAR, versões do runtime e cenários executados, sem incluir segredos ou endereços internos.

Alternativa considerada: compartilhar classes de teste unitário entre os módulos. Testes unitários não detectariam problemas de JSP, TLD, classloader, datasource ou empacotamento e serão apenas complementares.

### 5. Fase 2: Java 8 e WildFly 26.1.3

Primeiro a aplicação legada será executada com Java 8 no WildFly 9. Depois, sem alterar o namespace, a configuração será migrada para WildFly 26.1.3 em Java 8. Essa ordem separa falhas introduzidas pela JVM das introduzidas pelo servidor.

O build continuará usando Maven 3.8.9 ao trocar para Java 8 e ao entrar no WildFly 26, isolando essas mudanças de plataforma. No `CP-2C`, ele será alinhado ao Jakarta EE 8, cujas APIs ainda usam pacotes `javax.*`, as APIs do contêiner continuarão em `provided` e Maven será atualizado para 3.9.16 depois que o build não depender mais de uma JVM Java 7.

Somente ajustes necessários a compilação, configuração do WildFly, datasource, segurança, classloader e implantação serão feitos nessa fase. As bibliotecas legadas permanecerão inicialmente inalteradas para que o checkpoint isole a troca de plataforma.

### 6. Fase 3: destino final com gates técnicos internos

A fase final começará no checkpoint público `migration/02-java8-wildfly26` e será executada por três gates sequenciais. Cada gate deverá ficar verde antes do próximo, permitindo diagnóstico e rollback sem transformar estados temporários em fases públicas.

**Gate 3A — Java 17 no WildFly 26/EE 8 `javax`:** a aplicação passará primeiro a Java 17 no mesmo WildFly 26.1.3. Cada dependência será alterada em um commit isolado, seguido pelos testes de contrato e pela auditoria do WAR.

A política desse gate será:

1. atualizar para uma versão mantida quando ela continuar compatível com Java 17, EE 8 e a arquitetura existente;
2. remover APIs duplicadas quando o JDK já fornecer o contrato;
3. adiar para o gate Jakarta qualquer mudança que exija `jakarta.*` ou reescrita substancial;
4. registrar explicitamente exceções temporárias sem tratá-las como estado de produção.

O resultado previsto inclui MyBatis 3.5.19, XMLBeans 5.3.0 com tipos regenerados, dom4j 2.x, Reflections 0.10.2, driver Oracle compatível com Java 17/Oracle 19c, remoção de `xml-apis` e Geronimo StAX e substituição de Log4j 1 por uma implementação mantida com ponte temporária quando necessária. Commons FileUpload poderá permanecer provisoriamente na última linha 1.x compatível com `javax`, e Tiles continuará apenas até o gate seguinte.

**Gate 3B — Java 21 no WildFly 41/Jakarta EE 11:** o WAR aprovado no gate 3A será primeiro tentado sem transformação no WildFly 41 para capturar as falhas reais. Em seguida, a mesma árvore `app/` será executada com Java 21 e migrada para Jakarta EE 11. Java 21 isola a mudança de servidor, namespace e arquitetura antes da troca final da JVM.

A aplicação declarará:

```text
jakarta.platform:jakarta.jakartaee-web-api:11.0.0 (provided)
```

Os imports migrarão de `javax.servlet*`, `javax.servlet.jsp*`, `javax.servlet.jsp.tagext*`, `javax.servlet.jsp.jstl*` e `javax.el*` para `jakarta.*`. Pacotes Java SE como `javax.sql`, `javax.naming` e `javax.xml` permanecerão inalterados.

Tiles será substituído por tag files/includes sob `WEB-INF`; Commons FileUpload será substituído por `@MultipartConfig` e `jakarta.servlet.http.Part`; Reflections será substituído por registro explícito; e qualquer ponte temporária de logging será removida em favor do mecanismo final integrado ao WildFly.

O URI funcional da tag customizada permanecerá estável, mas os handlers migrarão para `jakarta.servlet.jsp.tagext`. As JSPs usarão preferencialmente `jakarta.tags.core`, `jakarta.tags.fmt` e `jakarta.tags.functions`.

**Gate 3C — Java 25 no WildFly 41:** depois da aprovação funcional e estrutural no Java 21, somente a JVM será alterada para Java 25. As falhas exclusivas dessa troca serão registradas, os contratos e auditorias serão repetidos e o estado aprovado receberá a tag pública `migration/03-final`. Uma execução adicional em Java 21 permanecerá na matriz de qualificação.

O gate 3C usará uma distribuição OpenJDK 25 e o WildFly 41 comunitário open source. A versão e a distribuição aprovadas serão fixadas por checksum e acompanhadas por origem e licença; Oracle JDK, JBoss EAP ou outro runtime proprietário não serão necessários para construir, executar ou validar o destino final. Antes do fechamento de `CP-3J`, será verificada a existência de atualização open source compatível, mas qualquer mudança será aprovada e fixada em vez de usar referências flutuantes como `latest`.

### 7. Persistência portátil e qualificação Oracle por fase

O contrato de schema e os dados de teste permanecerão funcionalmente estáveis para não misturar migração de banco com migração de plataforma. O Oracle será a referência oficial e terá scripts idempotentes próprios. O H2 terá scripts próprios de criação, massa e limpeza, semanticamente equivalentes, sem modificar ou simplificar os scripts Oracle para fazê-los passar no banco auxiliar.

Todos os runtimes publicarão `java:/jdbc/MigrationDS`, e a aplicação não selecionará o fornecedor por código de negócio:

| Perfil | Finalidade | Banco | Evidência |
|---|---|---|---|
| `ci-h2` | feedback automático em pull requests | H2 em memória, modo Oracle | `portable-ci` |
| `oracle` | qualificação de compatibilidade e fechamento de fase | Oracle Database 19c externo | `oracle-qualified` |

O perfil `ci-h2` não abrirá listener TCP ou console, não receberá credenciais e não empacotará H2 no WAR. A versão do H2 será fixada por fase, com origem, licença e checksum. No `CP-1D`, foram aprovados H2 1.4.200 e Zulu 7.56.0.11 CA/OpenJDK 7u352 depois de compará-los com o H2 1.3.173 fornecido pelo WildFly 9 e executar smokes nas duas distribuições Java 7. Ambos são infraestrutura de teste EOL. A reprodução oficial do baseline continua usando Oracle JDK 7u80.

Mappers, aliases, type handlers e limites transacionais serão compartilhados. SQL comum permanecerá único; diferenças inevitáveis poderão usar `databaseIdProvider` ou fragmentos explicitamente identificados por fornecedor. Toda divergência H2/Oracle será documentada para impedir que o adaptador de teste esconda uma incompatibilidade real.

Nas fases 1 e 2, o perfil `oracle` usará o driver legado necessário para reproduzir o ambiente. No gate Java 17 da fase 3, ele adotará um driver mantido compatível com Java 17 e Oracle 19c. Nos gates WildFly 41, o servidor provisionará `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0`; o driver não será empacotado no WAR.

O CI hospedado executará o perfil H2 em cada pull request aplicável a partir do `CP-1D`. A suíte Oracle será iniciada sob demanda a partir de uma máquina autorizada na rede interna e vinculará o relatório sanitizado ao commit e ao checksum do WAR testados. Não será necessário expor o Oracle à internet. Credenciais e URL serão fornecidas por ambiente ou secret local ignorado pelo controle de versão.

Uma aprovação H2 nunca promoverá automaticamente o estado Oracle. Checkpoints que alteram persistência, driver ou datasource e as tags `migration/01-legacy-baseline`, `migration/02-java8-wildfly26` e `migration/03-final` exigirão as duas evidências verdes.

Alternativas consideradas: empacotar drivers no WAR, o que duplicaria componentes e retiraria pool e credenciais do controle do WildFly; usar somente H2, o que esconderia diferenças Oracle; e conectar runners hospedados diretamente ao banco interno, o que exigiria exposição de rede incompatível com o isolamento desejado.

### 8. Falhas naturais antes de fixtures

Cada transição entre fases e cada gate da fase final começarão tentando executar o último estado verde no runtime seguinte antes de alterar o código. A saída dessa tentativa fornecerá a falha real, que será classificada, diagnosticada e relacionada ao menor conjunto de correções.

Fixtures opt-in serão usadas somente quando uma falha não puder ser reproduzida de modo determinístico dessa forma. O branch principal não ficará permanentemente quebrado.

Para cada incompatibilidade serão capturados: checkpoint de origem, runtime de destino, fase da falha, assinatura esperada, causa-raiz, correção, teste de regressão e instrução equivalente para uma aplicação real.

### 9. Auditoria e segurança do laboratório

Cada checkpoint público e gate interno produzirá inventário de dependências diretas/transitivas, versões de ferramentas, checksum do WAR e lista de `WEB-INF/lib`. A fase final rejeitará APIs do contêiner, `log4j:log4j`, Tiles, Commons FileUpload 1, `xml-apis`, Geronimo StAX, `ojdbc7` e Reflections.

Os runtimes WildFly 9 e WildFly 26 ficarão ligados apenas a loopback ou rede interna do ambiente de containers. Nenhuma credencial, binário proprietário do Java 7 ou segredo Oracle será versionado.

## Risks / Trade-offs

- [Java 7 e WildFly 9 são inseguros e difíceis de distribuir legalmente] → Isolar o runtime, impedir exposição externa, fixar checksums e permitir que o usuário forneça binários não redistribuíveis.
- [WildFly 26.1.3 também é uma linha antiga] → Tratá-lo apenas como ponte reproduzível da fase 2 e do primeiro gate interno, nunca como destino sustentável de produção.
- [Unificar a modernização mínima e o destino final aumenta o tamanho aparente da fase 3] → Exigir três gates internos verdes, commits isolados por dependência, evidências próprias e rollback para o último estado aprovado.
- [WildFly 41 recomenda Java 25, mas a certificação EE 11 publicada é para Java 17 e 21] → Executar o alvo principal em Java 25 e oferecer uma matriz de verificação adicional em Java 21.
- [O banner Oracle `19.0.0.0.0` não identifica o Release Update instalado] → Registrar o RU real no início da suíte Oracle e incluir esse valor no relatório.
- [O modo Oracle do H2 cobre apenas parte das diferenças entre bancos] → Manter DDL por fornecedor, classificar H2 somente como `portable-ci` e não considerar persistência ou fase qualificadas sem a suíte Oracle 19c.
- [A versão H2 compatível com Java 7 será histórica e poderá ter vulnerabilidades conhecidas] → Usá-la somente em memória, sem listener ou console, fora do WAR e em runner efêmero, registrando a exceção EOL e atualizando-a nos gates em que o Java permitir.
- [Commits intermediários podem ficar temporariamente quebrados] → Exigir que cada uma das três tags públicas e cada gate interno sejam verdes; falhas naturais não serão apresentadas como checkpoints.
- [Muitos checkpoints podem criar sobrecarga de revisão e CI] → Limitar cada entrega a até quatro tarefas de implementação, reutilizar um template único de PR e automatizar validação, evidências e convenção de commit.
- [O ambiente legado não pode ser reproduzido integralmente nos runners hospedados do GitHub] → Usar Java 7 redistribuível e H2 apenas como trilha portátil, manter Oracle JDK 7u80/Oracle 19c na validação interna documentada, exigir evidência do `doctor` e nunca enviar binários proprietários ou credenciais como artefatos públicos.
- [Maven 3.8.9 está em fim de vida apesar de ser a última versão disponível compatível com Java 7] → Fixar origem e checksum, restringi-lo ao caminho legado isolado e substituí-lo por Maven 3.9.16 no `CP-2C`.
- [O TLD histórico pode ser aceito de forma diferente por contêineres] → Testar o descritor original antes da normalização e registrar o comportamento observado.
- [Remover Reflections altera o mecanismo de extensibilidade] → Preservar o conjunto e a ordem dos validadores por contrato e documentar como adicionar novos validadores.
- [Logging gerenciado pelo servidor reduz portabilidade do formato de configuração] → Usar APIs padrão no código e encapsular a configuração específica do WildFly na área de runtime.
- [Dependências atuais podem avançar durante a implementação] → Fixar as versões aprovadas nesta proposta e executar uma revisão explícita antes de alterá-las.
- [Uma distribuição proprietária de Java ou do servidor pode entrar por conveniência operacional] → Auditar origem, licença e checksum do runtime final e reprovar Oracle JDK, JBoss EAP ou artefato sem proveniência open source documentada.

## Migration Plan

1. **Baseline legado:** concluir `CP-1A` a `CP-1G`, começando pelo repositório e ambiente, reconciliar a fundação H2/Oracle antes do fluxo web, construir a aplicação em `app/`, executar no Java 7/WildFly 9, congelar contratos, WAR, manifesto e tag `migration/01-legacy-baseline`.
2. **Modernização máxima com baixo impacto:** concluir `CP-2A` a `CP-2D`, executar primeiro no Java 8/WildFly 9, migrar para WildFly 26.1.3 ainda em `javax`, aprovar os contratos e criar `migration/02-java8-wildfly26`.
3. **Destino final:** concluir `CP-3A` a `CP-3K`, executar o gate Java 17/WildFly 26 e modernizar dependências; executar o gate Java 21/WildFly 41 e migrar para Jakarta EE 11; trocar somente a JVM para Java 25; validar Oracle, contratos e auditorias; e criar `migration/03-final`.

O rollback de uma fase pública consiste em selecionar a tag anterior, reprovisionar seu runtime e restaurar somente os dados de teste do laboratório. Dentro de uma fase, o rollback retorna ao commit de entrega e aos artefatos do último checkpoint parcial verde; dentro da fase 3, os gates continuam sendo pontos adicionais de retorno. Não haverá atualização in-place das instalações do WildFly nem alteração destrutiva do Oracle 19c.

A partir do `CP-1D`, o CI hospedado executará a trilha `portable-ci` com H2 em todos os pull requests aplicáveis. Os checkpoints de persistência e o encerramento de cada fase executarão adicionalmente a trilha `oracle-qualified` na rede interna. O relatório consolidado mostrará os dois estados separadamente.

## Open Questions

- Qual é o Release Update exato do Oracle Database 19c usado na validação?
- Quais tags, classes handler, mappers MyBatis e schemas XML da aplicação real deverão inspirar uma segunda rodada de fixtures?
- Quais versões intermediárias exatas serão aprovadas no gate Java 17 da fase 3 depois de confirmar suas dependências transitivas e compatibilidade com EE 8?
- A aplicação real utiliza APIs Oracle específicas, procedures, tipos `STRUCT/ARRAY`, cursores ou somente JDBC padrão?
