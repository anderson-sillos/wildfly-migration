## ADDED Requirements

### Requirement: Ambiente legado isolado
O laboratório SHALL iniciar a única árvore de código da aplicação em um ambiente isolado com Java 7u80, WildFly 9.0.2 e APIs Java EE da geração original, sem expor esse runtime obsoleto em interfaces de rede públicas.

#### Scenario: Inicialização do ambiente legado
- **WHEN** o usuário inicia o ambiente legado seguindo a documentação
- **THEN** a aplicação é implantada no WildFly 9.0.2 e fica acessível somente pelo endereço local documentado

#### Scenario: Versão incorreta do Java legado
- **WHEN** o ambiente é iniciado com uma JVM diferente da versão ou faixa aprovada para a simulação
- **THEN** a verificação de pré-requisitos encerra a execução com uma mensagem que informa a versão esperada e a encontrada

### Requirement: Fluxo representativo de pedidos
A aplicação legada SHALL permitir listar, criar e consultar pedidos, manter uma preferência em `HttpSession`, aplicar filtro de encoding/correlação e inicializar recursos por um `ServletContextListener`.

#### Scenario: Cadastro e consulta de pedido
- **WHEN** um usuário cadastra um pedido válido e abre sua página de detalhes
- **THEN** a aplicação apresenta os mesmos dados persistidos e um identificador estável do pedido

#### Scenario: Preferência de sessão
- **WHEN** o usuário altera uma preferência de exibição e navega para outra página na mesma sessão
- **THEN** a preferência permanece aplicada

### Requirement: Tecnologias de apresentação legadas
A aplicação legada SHALL conter JSP 2.0, JSTL 1.2, layout Apache Tiles 2.1.4 e ao menos uma biblioteca de tags customizada descrita por um TLD da família 2.0.

#### Scenario: Renderização por Tiles e tag customizada
- **WHEN** a página de detalhes de um pedido é renderizada
- **THEN** o layout Tiles compõe cabeçalho, conteúdo e rodapé e a tag customizada produz seu conteúdo esperado

#### Scenario: Inventário do tag handler
- **WHEN** o inventário da aplicação é gerado
- **THEN** ele relaciona cada elemento `<tag-class>` do TLD à classe Java correspondente e aos imports `javax.servlet.jsp.tagext` utilizados

### Requirement: Upload legado
A aplicação legada SHALL aceitar um anexo de pedido por meio de Commons FileUpload 1.2.2 e registrar metadados suficientes para comparar o resultado com a implementação moderna.

#### Scenario: Upload válido
- **WHEN** o usuário envia um arquivo permitido dentro do limite configurado
- **THEN** a aplicação associa nome normalizado, tamanho e tipo do arquivo ao pedido

#### Scenario: Upload acima do limite
- **WHEN** o usuário envia um arquivo maior que o limite configurado
- **THEN** a aplicação rejeita o upload com resposta funcional identificável pelos testes de contrato

### Requirement: Persistência MyBatis e Oracle
A aplicação legada SHALL usar MyBatis 3.4.5 com datasource JNDI e um driver da família `ojdbc7` para executar o fluxo de pedidos contra o banco configurado.

#### Scenario: Persistência pelo datasource
- **WHEN** um pedido é criado
- **THEN** o mapper MyBatis obtém a conexão pelo datasource JNDI e confirma os dados em uma transação

#### Scenario: Falha de datasource
- **WHEN** o datasource JNDI não está disponível
- **THEN** a aplicação registra e apresenta uma falha controlada sem incluir senha ou URL sensível na resposta HTTP

### Requirement: Processamento XML legado
A aplicação legada SHALL importar um pedido XML usando XMLBeans 2.3.0 e dom4j 1.6.1, preservando no inventário as dependências `xml-apis` 1.3.02 e Geronimo StAX 1.0 que precisam ser removidas na migração.

#### Scenario: Importação XML válida
- **WHEN** um documento compatível com o XSD do laboratório é enviado
- **THEN** a aplicação valida o documento e cria o pedido equivalente

#### Scenario: XML inválido
- **WHEN** o documento não atende ao XSD
- **THEN** a aplicação o rejeita e informa os erros de validação sem persistir um pedido parcial

### Requirement: Manifesto verificável do legado
O build legado SHALL gerar um manifesto com dependências diretas e transitivas, versões de ferramentas, conteúdo efetivo de `WEB-INF/lib` e checksum do WAR.

#### Scenario: Auditoria do WAR legado
- **WHEN** o WAR legado é empacotado
- **THEN** o relatório identifica quais bibliotecas vieram do Maven e quais APIs foram excluídas pelo escopo `provided`

#### Scenario: Ausência de JARs manuais no fonte
- **WHEN** a árvore de fontes é auditada
- **THEN** nenhum JAR manual é encontrado em `src/main/webapp/WEB-INF/lib`

### Requirement: Checkpoint imutável do baseline
O laboratório SHALL preservar o estado aprovado da fase 1 pela tag `migration/01-legacy-baseline`, sem criar uma segunda árvore de código para representar o destino moderno.

#### Scenario: Criação do checkpoint legado
- **WHEN** o WAR legado, o manifesto e os testes de contrato são aprovados
- **THEN** a tag `migration/01-legacy-baseline` identifica exatamente o código e a documentação que produziram essas evidências

#### Scenario: Reprodução posterior
- **WHEN** o usuário materializa o checkpoint legado em um Git worktree e inicia seu runtime
- **THEN** o WAR e os resultados normalizados dos contratos correspondem ao baseline registrado
