## ADDED Requirements

### Requirement: Evolução de uma única aplicação
O laboratório SHALL realizar toda a migração sobre uma única árvore `app/` e MUST preservar fases por tags Git e entregas parciais por commits identificáveis, acompanhados pelos WARs, manifestos e evidências aplicáveis, em vez de manter implementações independentes.

#### Scenario: Alteração de fase
- **WHEN** o laboratório inicia uma nova fase
- **THEN** as mudanças são aplicadas sobre o código aprovado no checkpoint anterior

#### Scenario: Comparação simultânea
- **WHEN** dois checkpoints precisam ser executados ao mesmo tempo
- **THEN** eles são materializados por tags ou commits de entrega e Git worktrees sem introduzir uma segunda linha permanente de desenvolvimento

### Requirement: Três fases públicas
O roteiro SHALL conter exatamente três fases públicas: baseline legado; modernização máxima com baixo impacto em Java 8/WildFly 26.1.3/EE 8 `javax`; e destino final Java 25/WildFly 41/Jakarta EE 11.

#### Scenario: Consulta do roteiro
- **WHEN** o usuário abre a documentação principal da migração
- **THEN** encontra somente as três fases numeradas, com objetivo, entrada, saída, verificação e rollback de cada uma

#### Scenario: Tarefa técnica interna
- **WHEN** uma fase exige várias alterações menores
- **THEN** elas permanecem como tarefas, commits ou gates internos e não criam uma quarta fase pública

### Requirement: Checkpoints parciais minimamente validáveis
Cada fase e gate SHALL ser particionado em checkpoints parciais identificados por `CP-<fase><letra>`, com no máximo quatro tarefas de implementação e uma tarefa de encerramento que execute a validação proporcional ao estado já construído.

#### Scenario: Checkpoint excede o limite
- **WHEN** um checkpoint planejado exige mais de quatro tarefas de implementação antes de produzir uma entrega validável
- **THEN** ele é dividido em checkpoints menores antes do início da implementação

#### Scenario: Encerramento aprovado
- **WHEN** build, testes, auditorias, documentação e diagnóstico aplicáveis ao checkpoint são aprovados
- **THEN** as evidências e o rollback são registrados e o checkpoint pode ser integrado ao branch principal

#### Scenario: Encerramento reprovado
- **WHEN** qualquer verificação obrigatória do checkpoint falha ou não possui evidência
- **THEN** a entrega não é integrada e o último commit de checkpoint aprovado permanece como referência verde

### Requirement: Entrega incremental pelo GitHub
O projeto SHALL configurar o repositório GitHub antes da criação da aplicação, SHALL usar uma branch e um pull request por checkpoint parcial e SHALL produzir no branch principal um commit de entrega `checkpoint(<ID>): <entrega>` somente depois das verificações obrigatórias.

#### Scenario: Bootstrap do repositório
- **WHEN** o checkpoint `CP-1A` é executado
- **THEN** o repositório, branch principal, proteções disponíveis, verificações obrigatórias, templates e convenções de branch, pull request e commit ficam documentados e configurados

#### Scenario: Publicação de uma entrega
- **WHEN** as verificações do pull request de um checkpoint são aprovadas
- **THEN** o merge por squash produz um único commit de entrega rastreável às tarefas, evidências e instrução de rollback

#### Scenario: Checkpoint parcial concluído
- **WHEN** um checkpoint parcial é integrado ao branch principal
- **THEN** nenhuma tag de fase é criada, exceto quando o mesmo commit também encerra uma das três fases públicas

### Requirement: Fase 2 de modernização máxima com baixo impacto
O laboratório SHALL migrar primeiro o baseline para Java 8 mantendo WildFly 9 e, depois, para WildFly 26.1.3 mantendo Java 8, EE 8, pacotes `javax.*`, Maven 3.8.9 e as bibliotecas legadas inicialmente inalteradas; somente no `CP-2C` SHALL atualizar a ferramenta de build para Maven 3.9.16.

#### Scenario: Isolamento da atualização da JVM
- **WHEN** a aplicação é executada pela primeira vez com Java 8
- **THEN** ela ainda usa o WildFly 9 e qualquer incompatibilidade observada é atribuível à mudança da JVM

#### Scenario: Isolamento da atualização do servidor
- **WHEN** a aplicação é implantada no WildFly 26.1.3
- **THEN** ela ainda usa Java 8 e `javax.*`, permitindo diagnosticar separadamente configuração, datasource, segurança e classloader

#### Scenario: Atualização isolada do Maven
- **WHEN** Java 8 e WildFly 26.1.3 já estão aprovados
- **THEN** o `CP-2C` atualiza Maven 3.8.9 para Maven 3.9.16 sem misturar essa alteração com a troca da JVM ou do servidor

#### Scenario: Conclusão da fase 2
- **WHEN** os contratos e a auditoria do WAR são aprovados no Java 8/WildFly 26.1.3
- **THEN** o estado é preservado como `migration/02-java8-wildfly26`

### Requirement: Fase 3 de destino final com gates técnicos
O laboratório SHALL concluir o destino final por gates sequenciais em Java 17/WildFly 26.1.3/EE 8 `javax`, Java 21/WildFly 41/Jakarta EE 11 e Java 25/WildFly 41/Jakarta EE 11, sem transformar os dois primeiros gates em fases públicas ou destinos permanentes de produção.

#### Scenario: Gate Java 17 e dependências
- **WHEN** a fase 3 inicia a partir de `migration/02-java8-wildfly26`
- **THEN** a aplicação é validada em Java 17/WildFly 26.1.3 e cada dependência compatível com EE 8/`javax` é atualizada isoladamente antes do gate Jakarta

#### Scenario: API duplicada com o JDK
- **WHEN** `xml-apis` ou Geronimo StAX duplica uma API fornecida pelo Java 17
- **THEN** a dependência é removida e os testes XML comprovam o uso correto de `java.xml`

#### Scenario: Atualização exige reescrita Jakarta
- **WHEN** uma biblioteca como Tiles não possui caminho mantido de baixo impacto em `javax`
- **THEN** ela é registrada como exceção temporária do gate Java 17 e obrigatoriamente substituída no gate Jakarta da mesma fase

#### Scenario: Gate Java 21 e Jakarta
- **WHEN** o gate Java 17 está verde
- **THEN** a aplicação é migrada para Java 21/WildFly 41/Jakarta EE 11, substituindo namespaces e componentes incompatíveis e aprovando contratos e auditorias antes da troca final da JVM

#### Scenario: Gate Java 25 e conclusão
- **WHEN** o gate Java 21/WildFly 41 está verde
- **THEN** somente a JVM é alterada para Java 25, as diferenças são registradas e todas as verificações finais são repetidas

#### Scenario: Conclusão da fase 3
- **WHEN** Java 25, WildFly 41, Jakarta EE 11, contratos, dependências, segurança, WAR e Oracle 19c são aprovados
- **THEN** o estado é preservado como `migration/03-final`, relacionando evidências dos gates internos sem publicar checkpoints adicionais

### Requirement: Substituição do Reflections pelo SCI padrão
Depois de atualizar Reflections para 0.10.2 no gate Java 17 e concluir a migração de namespace no Java 21/WildFly 41, o laboratório SHALL substituí-lo na atividade `3.33` do `CP-3G` pelo mecanismo padrão Jakarta Servlet `ServletContainerInitializer` com `@HandlesTypes(Validator.class)`, encapsulado por uma fachada própria e sem biblioteca externa de descoberta.

#### Scenario: Contrato legado preservado
- **WHEN** a atividade `3.33` substitui a ponte Reflections 0.10.2
- **THEN** o SCI e a fachada produzem o mesmo conjunto e a mesma ordem para validators elegíveis e descartam interfaces, classes abstratas e tipos que não implementam o contrato de validação

#### Scenario: Registro portátil do SCI
- **WHEN** o WAR final é inspecionado
- **THEN** um JAR interno em `WEB-INF/lib` contém a implementação do SCI e o arquivo `META-INF/services/jakarta.servlet.ServletContainerInitializer` aponta para essa implementação

#### Scenario: Separação entre infraestrutura e validators
- **WHEN** o mecanismo de descoberta é empacotado
- **THEN** o JAR interno contém `@Validator`, o contrato de validação, a fachada/registro, o SCI e o descritor de serviço, enquanto as implementações concretas podem permanecer em `WEB-INF/classes` ou em outros JARs aprovados de `WEB-INF/lib`

#### Scenario: Portabilidade do empacotamento
- **WHEN** o módulo WAR é implantado isoladamente ou dentro de um EAR
- **THEN** o SCI usa somente APIs Jakarta Servlet padrão e mantém o registro associado ao `ServletContext` do módulo web, sem depender de VFS ou API exclusiva do WildFly

### Requirement: Catálogo de incompatibilidades
O laboratório SHALL manter um catálogo versionado das incompatibilidades cobertas, classificadas por fase de compilação, empacotamento, implantação ou execução.

#### Scenario: Consulta de uma incompatibilidade
- **WHEN** o usuário seleciona um cenário do catálogo
- **THEN** encontra pré-condições, sintoma esperado, causa-raiz, correção e teste de regressão

#### Scenario: Cobertura mínima
- **WHEN** o catálogo inicial é validado
- **THEN** ele contém cenários para Java, namespaces Jakarta, APIs empacotadas, Tiles/TLD, upload, logging, MyBatis/reflexão, descoberta por annotation e substituição do Reflections, Oracle JDBC, XMLBeans, APIs XML duplicadas e dom4j

### Requirement: Falhas naturais e fixtures determinísticas
Cada transição entre fases e cada gate interno da fase final SHALL começar tentando executar o último estado verde no runtime seguinte para capturar incompatibilidades naturais; fixtures opt-in SHALL ser usadas somente quando essa reprodução não for determinística, e os três checkpoints públicos e gates internos MUST permanecer verdes.

#### Scenario: Tentativa antes da correção
- **WHEN** um checkpoint é executado pela primeira vez no runtime da fase seguinte
- **THEN** a falha ou o sucesso observado é capturado antes de qualquer mudança corretiva

#### Scenario: Execução de uma fixture complementar
- **WHEN** uma incompatibilidade não pode ser reproduzida naturalmente
- **THEN** uma fixture isolada falha na fase e categoria documentadas e considera essa falha esperada como sucesso do cenário

#### Scenario: Checkpoint público
- **WHEN** uma das três tags públicas é materializada
- **THEN** seu build e suas verificações padrão concluem com sucesso

### Requirement: Evidência antes e depois
Cada cenário de migração SHALL produzir evidência legível por máquina para o estado incompatível e para o estado corrigido.

#### Scenario: Comparação de evidências
- **WHEN** um cenário completo termina
- **THEN** o relatório relaciona o erro observado à correção e ao teste que passa depois dela

#### Scenario: Erro diferente do esperado
- **WHEN** a fixture falha por motivo diferente da assinatura ou categoria esperada
- **THEN** o cenário é marcado como falha do laboratório, não como reprodução bem-sucedida

### Requirement: Testes de contrato externos
A suíte de compatibilidade SHALL testar o checkpoint ativo por HTTP e pelo estado persistido, sem importar classes internas do WAR, e SHALL compará-lo com os resultados normalizados congelados na fase 1.

#### Scenario: Execução em um checkpoint
- **WHEN** a URL base do checkpoint ativo é fornecida
- **THEN** a suíte executa os mesmos fluxos do baseline e apresenta uma comparação consolidada

#### Scenario: Ambiente indisponível
- **WHEN** uma das aplicações não responde à verificação inicial
- **THEN** a suíte encerra com diagnóstico do ambiente ausente antes de executar os casos funcionais

### Requirement: Dupla qualificação de persistência
O laboratório SHALL executar em cada pull request aplicável uma trilha `portable-ci` com H2 em memória e SHALL executar uma trilha `oracle-qualified` contra Oracle Database 19c em ambiente autorizado na rede interna antes de encerrar checkpoints que qualificam persistência ou qualquer uma das três fases públicas.

#### Scenario: CI hospedado sem acesso ao Oracle
- **WHEN** um pull request é executado em runner hospedado sem rota ou credenciais para o Oracle interno
- **THEN** o perfil H2 executa os mesmos contratos HTTP e de estado portável sob `java:/jdbc/MigrationDS`, e o relatório conclui `portable-ci` sem declarar qualificação Oracle

#### Scenario: Paridade dos perfis
- **WHEN** a mesma revisão é testada nos perfis H2 e Oracle
- **THEN** ambos executam o mesmo conjunto de casos funcionais e as divergências específicas de fornecedor são identificadas separadamente

#### Scenario: Evidência vinculada ao artefato
- **WHEN** qualquer trilha de persistência conclui
- **THEN** o relatório registra perfil, commit, checksum do WAR, runtime e cenários executados sem registrar credencial, wallet, URL completa ou endereço interno

#### Scenario: Oracle indisponível no fechamento
- **WHEN** a trilha H2 passa, mas a evidência Oracle obrigatória do checkpoint ou da fase não está disponível
- **THEN** o CI portátil permanece aprovado, porém o checkpoint não recebe estado `oracle-qualified` e a fase não é encerrada

#### Scenario: Banco auxiliar não substitui o oficial
- **WHEN** H2 aceita um SQL ou comportamento que diverge do Oracle 19c
- **THEN** a divergência é registrada como limitação ou falha de paridade e o resultado H2 não prevalece sobre a suíte Oracle

### Requirement: Auditoria de dependências e empacotamento
O laboratório SHALL verificar a árvore Maven e o conteúdo do WAR em cada checkpoint para distinguir dependências declaradas, transitivas, fornecidas pelo servidor e empacotadas.

#### Scenario: API do servidor dentro do WAR moderno
- **WHEN** um JAR de Servlet, Pages, Tags ou EL é encontrado em `WEB-INF/lib` do WAR moderno
- **THEN** a auditoria falha e identifica a dependência que o introduziu

#### Scenario: Biblioteca removida reintroduzida transitivamente
- **WHEN** Log4j 1, Tiles, Commons FileUpload 1, Reflections, `xml-apis`, Geronimo StAX ou `ojdbc7` reaparece na árvore moderna
- **THEN** a auditoria falha mesmo que a dependência não esteja declarada diretamente

### Requirement: Roteiro incremental de migração
A documentação SHALL organizar as correções nas três fases públicas, gates internos e checkpoints parciais, com tarefas pequenas, pré-condição, alteração conceitual, verificação, commit de entrega e retorno ao último estado verde.

#### Scenario: Execução do roteiro
- **WHEN** o usuário segue as etapas na ordem publicada
- **THEN** cada etapa possui um critério objetivo de conclusão antes da próxima

#### Scenario: Investigação de uma falha real
- **WHEN** um erro semelhante ocorre na aplicação real
- **THEN** o usuário consegue localizar o cenário do laboratório pela fase, exceção ou biblioteca envolvida

### Requirement: Relatório de conclusão
O laboratório SHALL gerar um relatório consolidado com versões, ambientes executados, estados separados `portable-ci` e `oracle-qualified`, cenários aprovados, cenários não executados e limitações conhecidas.

#### Scenario: Suíte Oracle não executada
- **WHEN** credenciais Oracle 19c não são fornecidas
- **THEN** o relatório marca explicitamente a integração Oracle como não validada, sem tratá-la como aprovada

#### Scenario: Migração completamente validada
- **WHEN** builds, contratos H2 e Oracle, auditorias, segurança e integração Oracle são aprovados
- **THEN** o relatório declara a baseline moderna validada e relaciona todas as evidências
