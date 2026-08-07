## ADDED Requirements

### Requirement: Apresentação orientada ao público executivo
O material SHALL comunicar a proposta e os resultados do laboratório a gerentes e diretores em linguagem de decisão, com duração planejada entre 15 e 20 minutos e sem pressupor conhecimento técnico detalhado de Java ou WildFly.

#### Scenario: Leitura por gestor não técnico
- **WHEN** um gestor lê somente títulos, mensagens centrais e textos básicos
- **THEN** ele consegue identificar o problema, a proposta, os resultados, os limites e a decisão solicitada

#### Scenario: Termo técnico necessário
- **WHEN** um termo técnico é essencial para sustentar uma conclusão
- **THEN** o material relaciona o termo a impacto de negócio, risco ou controle operacional

### Requirement: Narrativa executiva completa e resumida
O material SHALL conter entre 10 e 12 slides e MUST cobrir, em ordem lógica, contexto do legado, proposta do laboratório, planejamento, método de evidência, resultado, incompatibilidades, lições, limitações, aplicação real e próximos passos.

#### Scenario: Revisão da sequência
- **WHEN** a organização dos slides é revisada
- **THEN** a narrativa progride de problema para proposta, prova, aplicação e decisão sem exigir consulta a outro documento

#### Scenario: Controle de extensão
- **WHEN** a versão textual é concluída
- **THEN** ela possui no máximo 12 slides de conteúdo principal, excluindo eventual seção de fontes

### Requirement: Estrutura mínima por slide
Cada slide SHALL conter um título, uma mensagem central, texto básico, evidências de apoio e notas breves do apresentador. O texto básico SHOULD privilegiar de três a cinco pontos curtos e não duplicar integralmente as notas.

#### Scenario: Slide completo
- **WHEN** qualquer slide de conteúdo é inspecionado
- **THEN** os cinco elementos obrigatórios estão presentes e a mensagem principal pode ser entendida isoladamente

### Requirement: Rastreabilidade das afirmações
Toda afirmação quantitativa, versão de plataforma, resultado de teste ou conclusão apresentada como comprovada SHALL apontar para uma fonte versionada do repositório.

#### Scenario: Resultado comprovado
- **WHEN** um slide declara que um comportamento, runtime ou contrato foi validado
- **THEN** o campo de evidências referencia o documento, catálogo ou artefato que sustenta a declaração

#### Scenario: Afirmação sem evidência suficiente
- **WHEN** uma afirmação relevante não pode ser ligada a uma evidência existente
- **THEN** ela é removida, apresentada como hipótese ou identificada como recomendação a validar

### Requirement: Separação entre prova, recomendação e limitação
O material MUST distinguir resultados comprovados no laboratório, recomendações para uma aplicação real e limitações do escopo, sem apresentar o laboratório como garantia automática de compatibilidade, prazo ou custo.

#### Scenario: Generalização para aplicação real
- **WHEN** uma lição do laboratório é aplicada a outro sistema
- **THEN** o texto informa que inventário, baseline e qualificação próprios continuam necessários

#### Scenario: Item não coberto
- **WHEN** o conteúdo menciona carga, cluster, integrações, segurança específica, procedures ou outros itens não exercitados
- **THEN** esses itens aparecem como limitações ou atividades futuras, não como resultados aprovados

### Requirement: Planejamento e comprovações do laboratório
O material SHALL representar as três fases públicas e os gates intermediários de forma coerente com o histórico do projeto, incluindo a evolução de Java 7/WildFly 9 até OpenJDK 25/WildFly 41/Jakarta EE 11 e os contratos executados em H2 e Oracle.

#### Scenario: Resumo das fases
- **WHEN** o slide de planejamento é lido
- **THEN** ele diferencia baseline legado, modernização de baixo impacto e destino final

#### Scenario: Resumo das comprovações
- **WHEN** o slide de resultados é lido
- **THEN** ele apresenta somente números, versões e qualificações confirmados pelas evidências finais

### Requirement: Aplicação do método em migração real
O material SHALL propor um roteiro adaptável para uma aplicação real que cubra inventário, baseline, modernização incremental, dependências, Jakarta, qualificação oficial, corte e rollback.

#### Scenario: Uso como ponto de partida
- **WHEN** a liderança seleciona uma aplicação piloto
- **THEN** o roteiro permite iniciar enquadramento e baseline sem assumir que o laboratório substitui a análise dessa aplicação

### Requirement: Encerramento orientado à decisão
O último slide SHALL apresentar próximos passos concretos e as decisões esperadas da liderança, incluindo seleção de aplicação piloto, definição de responsáveis e autorização para inventário e baseline.

#### Scenario: Reunião executiva concluída
- **WHEN** a apresentação chega ao encerramento
- **THEN** os participantes conseguem identificar quais decisões podem tomar e qual entrega será produzida primeiro

### Requirement: Independência de layout e ferramenta
A fonte textual SHALL ser utilizável antes da escolha de identidade visual ou ferramenta de apresentação e MUST evitar instruções que imponham PowerPoint, Google Slides ou outro formato específico.

#### Scenario: Revisão editorial anterior ao design
- **WHEN** o conteúdo é revisado sem um arquivo visual
- **THEN** organização, mensagens, evidências e notas podem ser aprovadas integralmente em Markdown
