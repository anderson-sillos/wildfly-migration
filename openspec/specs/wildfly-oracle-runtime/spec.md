# Runtime WildFly e Oracle

## Purpose

Define os runtimes, datasources, drivers, perfis portáteis e qualificação Oracle usados pelas fases do laboratório.

## ADDED Requirements

### Requirement: Runtime WildFly versionado
O laboratório SHALL fornecer configuração reproduzível para WildFly 9.0.2 na fase 1, WildFly 26.1.3 na fase 2 e no gate Java 17 da fase 3, e WildFly 41.0.0.Final nos gates Java 21 e Java 25 da fase 3, com verificação das versões efetivamente iniciadas.

#### Scenario: Runtime correspondente ao checkpoint
- **WHEN** uma das três fases ou um gate interno é iniciado
- **THEN** a verificação confirma a combinação de WildFly, Java e checkpoint antes de implantar o WAR

#### Scenario: Distribuição divergente
- **WHEN** uma distribuição ou imagem com versão diferente é usada
- **THEN** o ambiente falha rapidamente e informa a versão detectada

### Requirement: Matriz de Java do destino
O runtime SHALL fornecer Java 7 para a fase 1, Java 8 para a fase 2 e, na fase 3, Java 17 para o gate de dependências, Java 21 para o gate Jakarta e Java 25 para o destino final; o checkpoint final SHALL permitir uma execução adicional de qualificação em Java 21.

#### Scenario: Matriz dos três checkpoints
- **WHEN** a matriz completa é executada
- **THEN** cada tag pública é construída e testada na combinação de Java e WildFly definida para sua fase e os gates internos são verificados antes do checkpoint final

#### Scenario: Execução de qualificação
- **WHEN** a variante Java 21 é solicitada
- **THEN** os mesmos testes de contrato são executados e as diferenças são registradas

### Requirement: Driver Oracle provisionado no servidor
O runtime SHALL preservar o driver legado necessário nas fases 1 e 2, SHALL usar no gate Java 17 da fase 3 um driver mantido compatível com Java 17/Oracle 19c e SHALL provisionar `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` no WildFly 41 da fase 3 sem depender de uma cópia dentro do WAR final.

#### Scenario: Driver final registrado
- **WHEN** o WildFly 41 da fase 3 conclui a inicialização
- **THEN** o driver Oracle aparece na configuração de drivers JDBC com a versão esperada

#### Scenario: Driver intermediário registrado
- **WHEN** o gate Java 17/WildFly 26 da fase 3 conclui a inicialização
- **THEN** o driver selecionado para Java 17 e Oracle 19c aparece no inventário da fase e não é confundido com o destino final

#### Scenario: Driver duplicado no WAR
- **WHEN** qualquer `ojdbc*.jar` é encontrado no WAR moderno
- **THEN** a verificação de empacotamento falha

### Requirement: Perfil H2 portátil
O runtime SHALL fornecer um perfil H2 em memória para o CI hospedado, SHALL fixar uma versão compatível com o Java de cada fase, SHALL registrar origem, licença e checksum e MUST NOT empacotar o driver H2 no WAR ou expor console ou listener de rede.

#### Scenario: Seleção do H2 para Java 7
- **WHEN** o perfil portátil do baseline é preparado
- **THEN** uma versão H2 compatível com Java 7 é comprovada no WildFly 9, registrada como infraestrutura de teste EOL quando aplicável e isolada do artefato da aplicação

#### Scenario: Atualização por fase
- **WHEN** uma fase adota uma JVM que permite uma versão H2 mantida mais recente
- **THEN** a versão de teste é revisada, fixada e submetida aos mesmos contratos antes de substituir a anterior

#### Scenario: Schema equivalente
- **WHEN** o perfil H2 é iniciado
- **THEN** scripts H2 próprios criam e populam um schema funcionalmente equivalente sem modificar os scripts Oracle canônicos

#### Scenario: Isolamento do H2
- **WHEN** runtime, portas publicadas e conteúdo do WAR são auditados
- **THEN** H2 existe somente como componente do runtime de teste em memória e não disponibiliza console, listener TCP ou JAR em `WEB-INF/lib`

### Requirement: Datasource JNDI
O runtime SHALL publicar `java:/jdbc/MigrationDS` tanto no perfil H2 portátil quanto no perfil Oracle oficial, com pool gerenciado pelo WildFly, validação de conexão e transações compatíveis com o uso do MyBatis, sem exigir seleção de fornecedor pelo código de negócio.

#### Scenario: Teste de conexão
- **WHEN** as configurações Oracle válidas são fornecidas
- **THEN** o comando de teste do datasource confirma uma conexão com Oracle Database 19c

#### Scenario: Datasource portátil
- **WHEN** o perfil `ci-h2` é selecionado
- **THEN** o mesmo nome JNDI aponta para um banco H2 em memória sem exigir qualquer segredo Oracle

#### Scenario: JNDI indisponível
- **WHEN** o WAR é implantado sem o datasource
- **THEN** a implantação ou verificação de saúde falha com diagnóstico que identifica `java:/jdbc/MigrationDS`

### Requirement: Segredos externos
URL, usuário, senha, wallet e demais segredos de banco MUST ser fornecidos fora do controle de versão e MUST NOT aparecer em logs, relatórios ou respostas HTTP.

#### Scenario: Detecção de segredo versionado
- **WHEN** a auditoria encontra um valor de credencial em arquivo rastreável do projeto
- **THEN** a verificação falha e indica o arquivo sem reproduzir o segredo

#### Scenario: Falha de autenticação
- **WHEN** o Oracle rejeita as credenciais
- **THEN** o relatório preserva o código e a categoria do erro sem imprimir a senha

### Requirement: Qualificação do Oracle 19c
A suíte Oracle SHALL ser executável a partir de ambiente autorizado na rede interna, SHALL registrar a versão completa e o Release Update observados e SHALL testar transações, sequences, paginação, timestamps, CLOB/BLOB e os recursos Oracle efetivamente usados pelo laboratório. Ela MUST permanecer separada do resultado H2 e MUST NOT exigir exposição do banco à internet.

#### Scenario: Registro da versão do banco
- **WHEN** a suíte estabelece conexão
- **THEN** ela inclui no relatório a versão retornada pelo servidor e distingue a linha 19c do Release Update instalado

#### Scenario: Compatibilidade do driver
- **WHEN** a suíte é executada com `ojdbc17` contra Oracle 19c
- **THEN** todas as operações JDBC selecionadas são concluídas ou uma incompatibilidade é registrada com evidência reproduzível

#### Scenario: Rollback transacional
- **WHEN** uma operação de pedido falha depois de iniciar uma transação
- **THEN** nenhuma alteração parcial permanece no banco

#### Scenario: Evidência da rede interna
- **WHEN** a suíte Oracle termina em uma máquina autorizada
- **THEN** ela produz relatório sanitizado vinculado ao commit e ao checksum do WAR sem publicar endereço interno, URL JDBC completa, usuário, senha ou wallet

### Requirement: Isolamento de rede
O ambiente legado SHALL ficar restrito a loopback ou rede interna e o ambiente moderno SHALL expor somente as portas necessárias para os testes locais.

#### Scenario: Inspeção de portas
- **WHEN** os runtimes estão ativos
- **THEN** a verificação lista as portas publicadas e falha se o legado estiver vinculado a uma interface pública

### Requirement: Ciclo de vida reproduzível
O runtime SHALL oferecer operações documentadas para preparar, iniciar, verificar, parar e limpar somente os recursos da fase ou gate selecionado e SHALL obter o código da tag correspondente quando reproduzir um checkpoint público anterior.

#### Scenario: Inicialização limpa
- **WHEN** o usuário prepara e inicia o laboratório a partir de um checkout limpo
- **THEN** todos os artefatos derivados são recriados sem depender de estado manual não documentado

#### Scenario: Limpeza
- **WHEN** o usuário executa a limpeza
- **THEN** apenas containers, redes, volumes e arquivos temporários identificados como pertencentes ao laboratório são removidos

### Requirement: Maven versionado por fase
O laboratório SHALL usar Maven 3.8.9 no baseline Java 7 e durante `CP-2A` e `CP-2B`, SHALL registrar sua origem e checksum e SHALL atualizar para Maven 3.9.16 somente no `CP-2C`.

#### Scenario: Build legado reproduzível
- **WHEN** um checkpoint da fase 1 é construído
- **THEN** Maven 3.8.9 executa com Java 7u80 e a versão efetiva corresponde ao manifesto aprovado

#### Scenario: Maven do ambiente modernizado
- **WHEN** o `CP-2C` é validado
- **THEN** Maven 3.9.16 executa com Java 8 ou superior e Maven 3.8.9 deixa de ser a ferramenta ativa do build

### Requirement: Documentação e diagnóstico do ambiente
O primeiro checkpoint parcial SHALL documentar a instalação ou o fornecimento de Git, ferramenta de acesso ao GitHub, runtime de containers, Java 7/8/17/21/25, Maven 3.9.16, WildFly 9/26/41 e acesso ao Oracle 19c. No `CP-1B`, a documentação e o diagnóstico SHALL incorporar Maven 3.8.9 como ferramenta EOL do legado. No `CP-1D`, eles SHALL documentar a distribuição Java 7 redistribuível, o H2 de teste, os perfis `ci-h2` e `oracle` e a execução Oracle na rede interna. Em todos os checkpoints, a documentação SHALL identificar quais distribuições são open source, proprietárias, restritas ou EOL e o diagnóstico `doctor` SHALL validar somente os pré-requisitos exigidos pelo checkpoint e pelo perfil selecionados.

#### Scenario: Preparação a partir de checkout limpo
- **WHEN** uma pessoa segue a documentação em um checkout limpo e executa o diagnóstico para o checkpoint atual
- **THEN** ela obtém instruções, versões detectadas, itens aprovados, itens ausentes e comandos de correção sem depender de conhecimento não documentado

#### Scenario: Componente proprietário ou restrito
- **WHEN** Java 7u80, driver Oracle ou outro componente não pode ser redistribuído pelo projeto
- **THEN** a documentação informa como fornecê-lo externamente e validar seu checksum sem versionar o binário

#### Scenario: Pré-requisito de fase futura
- **WHEN** Oracle ou um runtime de uma fase futura ainda não é necessário para validar o checkpoint atual
- **THEN** o diagnóstico o marca como não exigido em vez de reprovar a entrega parcial

#### Scenario: Diagnóstico do perfil portátil
- **WHEN** o diagnóstico é executado com `ci-h2`
- **THEN** ele valida Java, Maven, WildFly e H2 fixados sem exigir URL, usuário, senha, wallet ou driver Oracle

#### Scenario: Diagnóstico do perfil Oracle
- **WHEN** o diagnóstico é executado com `oracle`
- **THEN** ele exige o driver e a configuração Oracle aplicáveis, testa somente a conectividade autorizada e não imprime valores sensíveis

#### Scenario: Segredo no diagnóstico
- **WHEN** variáveis de credencial são verificadas
- **THEN** o diagnóstico informa presença e validade estrutural sem imprimir o valor

#### Scenario: Destino final open source
- **WHEN** o diagnóstico valida o checkpoint `CP-3J` ou `migration/03-final`
- **THEN** ele exige OpenJDK e WildFly comunitário com origem, licença, versão e checksum aprovados e rejeita uma dependência de runtime proprietário

