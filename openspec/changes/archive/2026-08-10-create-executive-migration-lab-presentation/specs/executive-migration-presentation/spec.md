## ADDED Requirements

### Requirement: Apresentação orientada ao público executivo
O material SHALL comunicar a proposta e os resultados do laboratório a gerentes e diretores em linguagem de decisão, com duração total máxima de 20 minutos e sem pressupor conhecimento técnico detalhado de Java ou WildFly.

#### Scenario: Leitura por gestor não técnico
- **WHEN** um gestor lê somente títulos, mensagens centrais e textos básicos
- **THEN** ele consegue identificar o problema, a proposta, os resultados, os limites e a decisão solicitada

#### Scenario: Termo técnico necessário
- **WHEN** um termo técnico é essencial para sustentar uma conclusão
- **THEN** o material relaciona o termo a impacto de negócio, risco ou controle operacional

### Requirement: Narrativa organizada em três partes
O material SHALL separar explicitamente a apresentação em problema/proposta/planejamento, provas/incompatibilidades/lições e aplicação real/decisões, sem impor uma quantidade máxima de slides além do limite temporal.

#### Scenario: Revisão da sequência
- **WHEN** a organização dos slides é revisada
- **THEN** as três partes estão identificadas e a narrativa progride de problema para proposta, prova, aplicação e decisão

#### Scenario: Controle de duração
- **WHEN** os tempos-alvo de todos os slides são somados
- **THEN** o total não excede 20 minutos

### Requirement: Estrutura mínima por slide
Cada slide SHALL conter título, tempo-alvo, mensagem central, texto básico e notas breves do apresentador. O texto básico SHOULD privilegiar pontos curtos e não duplicar integralmente as notas. As fontes de apoio MUST permanecer fora dos slides, em uma seção editorial separada e organizada por slide.

#### Scenario: Slide completo
- **WHEN** qualquer slide de conteúdo é inspecionado
- **THEN** os cinco elementos obrigatórios estão presentes e a mensagem principal pode ser entendida isoladamente

### Requirement: Quadro de compatibilidade WildFly e Java
A Parte 1 SHALL incluir o quadro WildFly × Java versionado no projeto e MUST explicar as legendas necessárias para interpretar ciclo de vida, compatibilidade e preferência de runtime.

#### Scenario: Leitura executiva do quadro
- **WHEN** o quadro é apresentado
- **THEN** as combinações do legado, da ponte e do destino são destacadas sem transformar compatibilidade técnica em recomendação automática de produção

### Requirement: Construção com Codex, SDD e OpenSpec
A Parte 1 SHALL registrar que o laboratório foi integralmente construído com uso de IA por meio do Codex, sob direção, revisão, testes e aprovação humana, e SHALL resumir SDD e OpenSpec como mecanismos de especificação e rastreabilidade.

#### Scenario: Explicação resumida do OpenSpec
- **WHEN** o slide de processo é lido
- **THEN** ele apresenta proposta, design, specs, tarefas e evidências/checkpoints em sequência compreensível para o público executivo

#### Scenario: Responsabilidade humana
- **WHEN** o uso de IA é descrito
- **THEN** o material não sugere autonomia irrestrita nem substituição da responsabilidade humana por decisões e aprovações

### Requirement: Rastreabilidade das afirmações
Toda afirmação quantitativa, versão de plataforma, resultado de teste ou conclusão apresentada como comprovada SHALL apontar para uma fonte versionada do repositório.

#### Scenario: Resultado comprovado
- **WHEN** um slide declara que um comportamento, runtime ou contrato foi validado
- **THEN** o mapa de referências editoriais associa o slide ao documento, catálogo ou artefato que sustenta a declaração

#### Scenario: Afirmação sem evidência suficiente
- **WHEN** uma afirmação relevante não pode ser ligada a uma evidência existente
- **THEN** ela é removida, apresentada como hipótese ou identificada como recomendação a validar

### Requirement: Separação entre prova, recomendação e limitação
O material MUST distinguir resultados comprovados no laboratório, recomendações para uma aplicação real e limitações do escopo, sem apresentar o laboratório ou o uso de IA como garantia automática de compatibilidade, prazo ou custo.

#### Scenario: Generalização para aplicação real
- **WHEN** uma lição do laboratório é aplicada a outro sistema
- **THEN** o texto informa que inventário, baseline e qualificação próprios continuam necessários

#### Scenario: Item não coberto
- **WHEN** o conteúdo menciona carga, cluster, integrações, segurança específica, procedures ou outros itens não exercitados
- **THEN** esses itens aparecem como limitações ou atividades futuras, não como resultados aprovados

### Requirement: Planejamento e comprovações do laboratório
O material SHALL justificar as três fases públicas e representar os gates intermediários de forma coerente com o histórico do projeto, incluindo a evolução de Java 7/WildFly 9 até OpenJDK 25/WildFly 41/Jakarta EE 11 e os contratos executados em H2 e Oracle.

#### Scenario: Razão das três fases
- **WHEN** o slide de planejamento é lido
- **THEN** ele explica baseline, modernização de baixo impacto e destino final como separação deliberada de riscos

#### Scenario: Resumo das comprovações
- **WHEN** o slide de resultados é lido
- **THEN** ele apresenta somente números, versões e qualificações confirmados pelas evidências finais

### Requirement: Decisões por componente e biblioteca
A Parte 2 SHALL listar os principais componentes e bibliotecas do legado e SHALL informar para cada um a decisão tomada, o destino e a justificativa resumida.

#### Scenario: Consulta das decisões
- **WHEN** as tabelas de componentes são revisadas
- **THEN** Java, Maven, WildFly, Java/Jakarta EE, H2, Oracle/JDBC, MyBatis, Log4j, Commons FileUpload, Reflections, Tiles, XMLBeans, dom4j, APIs XML e APIs web/TLD possuem decisão explícita

#### Scenario: Biblioteca removida
- **WHEN** uma biblioteca não permanece no destino
- **THEN** o material identifica o contrato preservado e o mecanismo substituto ou a API fornecida pela plataforma

### Requirement: Aplicação do método em migração real
A Parte 3 SHALL propor um roteiro adaptável para uma aplicação real que cubra inventário, baseline, modernização incremental, dependências, Jakarta, qualificação oficial, limites, corte e rollback.

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
- **THEN** organização, mensagens, referências editoriais, tempos e notas podem ser aprovados integralmente em Markdown
