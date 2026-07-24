## ADDED Requirements

### Requirement: Plataforma moderna suportada
O checkpoint final da mesma aplicação iniciada na fase 1 SHALL compilar para Java 25, executar no WildFly 41.0.0.Final e declarar Jakarta EE Web Profile 11.0.0 com escopo `provided`.

#### Scenario: Build moderno
- **WHEN** o build é executado com Java 25 e Maven 3.9.16
- **THEN** ele produz um WAR implantável sem depender de Maven 4 release candidate

#### Scenario: Implantação no WildFly moderno
- **WHEN** o WAR corrigido é implantado no WildFly 41
- **THEN** o servidor inicia a aplicação sem erro de linkage entre namespaces `javax` e `jakarta`

### Requirement: Runtime final exclusivamente open source
O checkpoint final MUST usar uma distribuição OpenJDK e a distribuição comunitária open source do WildFly, MUST registrar versão, origem, licença e checksum de ambas e MUST NOT depender de Oracle JDK, JBoss EAP ou outro runtime proprietário.

#### Scenario: Auditoria da distribuição Java
- **WHEN** o ambiente final é preparado
- **THEN** a JVM é identificada como uma distribuição OpenJDK aprovada e sua proveniência corresponde ao manifesto do checkpoint

#### Scenario: Auditoria da distribuição WildFly
- **WHEN** o servidor final é iniciado
- **THEN** ele é identificado como WildFly comunitário open source na versão e checksum aprovados

#### Scenario: Runtime proprietário detectado
- **WHEN** Oracle JDK, JBoss EAP ou uma distribuição sem origem e licença open source documentadas é detectada no destino final
- **THEN** a validação do checkpoint falha antes da implantação do WAR

### Requirement: Equivalência funcional
O checkpoint final SHALL preservar o contrato funcional observável congelado em `migration/01-legacy-baseline` para listagem, criação, consulta, sessão, upload e importação XML de pedidos.

#### Scenario: Contrato da fase 3 aprovado
- **WHEN** a suíte externa executa o mesmo conjunto de casos contra o checkpoint final
- **THEN** os resultados normalizados e os efeitos persistidos equivalem ao baseline congelado

#### Scenario: Divergência funcional
- **WHEN** uma resposta moderna diverge de uma regra de negócio congelada no baseline
- **THEN** a suíte falha e apresenta a diferença entre os dois ambientes

### Requirement: APIs Jakarta e pacotes Java SE
Na fase 3, durante o gate Java 21/WildFly 41, o código MUST migrar os pacotes EE `javax.*` para `jakarta.*` em Servlet, Pages, tag handlers, JSTL e EL, e MUST preservar pacotes `javax.*` pertencentes ao Java SE, incluindo `javax.sql`, `javax.naming` e `javax.xml`.

#### Scenario: Compilação dos componentes web
- **WHEN** Servlets, filtros, listeners e tag handlers modernos são compilados
- **THEN** nenhuma referência binária a `javax.servlet`, `javax.servlet.jsp` ou `javax.el` permanece

#### Scenario: Uso de DataSource e XML
- **WHEN** o código moderno usa datasource JNDI e StAX
- **THEN** ele continua importando as APIs Java SE `javax.sql`, `javax.naming` e `javax.xml.stream`

### Requirement: Apresentação sem Tiles
Na fase 3, a aplicação SHALL renderizar as mesmas regiões de layout usando JSP tag files ou includes protegidos sob `WEB-INF`, removendo a exceção Apache Tiles registrada temporariamente no gate Java 17.

#### Scenario: Renderização do layout moderno
- **WHEN** uma JSP de conteúdo é requisitada
- **THEN** cabeçalho, conteúdo e rodapé são compostos sem classes ou descritores Tiles

#### Scenario: Acesso direto a fragmento
- **WHEN** um cliente tenta acessar diretamente um tag file ou fragmento sob `WEB-INF`
- **THEN** o contêiner impede o acesso HTTP direto

### Requirement: Tag library compatível
A fase 3 SHALL preservar o URI e o comportamento da tag customizada, migrando seus handlers de `javax.servlet.jsp.tagext` para `jakarta.servlet.jsp.tagext`.

#### Scenario: TLD histórico
- **WHEN** o TLD histórico é implantado na fixture de compatibilidade do WildFly 41
- **THEN** o resultado de aceitação ou rejeição é capturado antes de qualquer normalização do descritor

#### Scenario: Handler moderno
- **WHEN** uma JSP invoca a tag customizada na aplicação corrigida
- **THEN** o handler Jakarta é carregado e produz a saída definida pelo contrato

### Requirement: Multipart nativo e seguro
Na fase 3, a aplicação SHALL substituir a linha Commons FileUpload mantida temporariamente no gate Java 17 por `@MultipartConfig` e `jakarta.servlet.http.Part`, com limites explícitos, nome normalizado, validação de tipo e armazenamento fora da raiz pública.

#### Scenario: Upload moderno válido
- **WHEN** um arquivo permitido dentro do limite é enviado
- **THEN** ele é processado sem Commons FileUpload e os metadados equivalem aos do contrato legado

#### Scenario: Nome de arquivo malicioso
- **WHEN** o upload contém caminho relativo, absoluto ou sequência de traversal no nome
- **THEN** a aplicação rejeita ou normaliza o nome sem escrever fora do diretório permitido

#### Scenario: Limite excedido
- **WHEN** o tamanho da requisição ou do arquivo excede o limite
- **THEN** a aplicação rejeita o upload e remove arquivos temporários associados

### Requirement: Dependências modernas
O checkpoint final SHALL usar MyBatis 3.5.19, XMLBeans 5.3.0 e dom4j 2.2.0 e MUST excluir Log4j 1 ou sua ponte temporária, Commons FileUpload 1, Reflections, Tiles, `xml-apis`, Geronimo StAX e `ojdbc7`.

#### Scenario: Verificação de dependências proibidas
- **WHEN** a árvore de dependências e o WAR moderno são auditados
- **THEN** nenhuma dependência proibida direta, transitiva ou empacotada é encontrada

#### Scenario: Mapeamentos MyBatis preservados
- **WHEN** os testes de persistência modernos são executados
- **THEN** mappers XML, aliases, type handlers e limites transacionais produzem os resultados esperados

### Requirement: XML moderno e seguro
A aplicação moderna SHALL regenerar os tipos XMLBeans a partir do XSD mantido no projeto e configurar o parsing XML para impedir resolução não autorizada de entidades e recursos externos.

#### Scenario: Regeneração reproduzível
- **WHEN** o build começa sem classes XMLBeans geradas
- **THEN** ele regenera o type system a partir dos XSDs e compila a aplicação

#### Scenario: Tentativa de entidade externa
- **WHEN** um XML referencia uma entidade externa não permitida
- **THEN** a importação é rejeitada sem realizar acesso a arquivo local ou rede

#### Scenario: Documento legítimo
- **WHEN** um XML válido usa namespaces e encoding suportados
- **THEN** o pedido é importado com os mesmos dados do baseline

### Requirement: Logging controlado pelo contêiner
Na fase 3, a aplicação SHALL remover qualquer ponte temporária introduzida no gate Java 17 e registrar eventos pelo mecanismo integrado ao WildFly sem empacotar Log4j 1 ou um backend concorrente no WAR.

#### Scenario: Correlação de logs
- **WHEN** uma requisição atravessa filtro, servlet e persistência
- **THEN** os registros incluem o identificador de correlação sem expor credenciais ou conteúdo sensível do upload

#### Scenario: Configuração do MyBatis
- **WHEN** o MyBatis emite mensagens de diagnóstico
- **THEN** elas são encaminhadas ao logging selecionado para o WildFly sem usar `org.apache.ibatis.logging.log4j.Log4jImpl`

### Requirement: Checkpoint final imutável
O laboratório SHALL preservar o estado aprovado da fase 3 como `migration/03-final`, relacionando-o aos dois checkpoints públicos anteriores e às evidências dos gates internos da mesma árvore de código.

#### Scenario: Conclusão do destino final
- **WHEN** build, implantação, contratos, auditorias, segurança e integração Oracle 19c são aprovados
- **THEN** a tag `migration/03-final` identifica o código, o runtime e as evidências finais

#### Scenario: Rastreabilidade da evolução
- **WHEN** o usuário compara as três tags públicas e consulta as evidências dos gates internos
- **THEN** ele consegue observar a evolução incremental da mesma aplicação sem reconciliar dois projetos diferentes
