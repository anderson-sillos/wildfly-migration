# Modernização com controle — apresentação executiva do laboratório

## Orientação editorial

- **Público:** gerentes e diretores responsáveis por aplicações, tecnologia, operações, segurança, dados e continuidade.
- **Objetivo:** apresentar o risco do legado, a proposta e a construção do laboratório, as constatações comprovadas, as lições aprendidas e um caminho para aplicar o método a uma migração real.
- **Duração total:** 20 minutos.
- **Organização:** três grandes partes, além da abertura.
- **Escopo desta versão:** conteúdo textual canônico, apresentação PowerPoint executiva e gerador versionado do artefato visual.
- **Princípio de comunicação:** diferenciar `Comprovado no laboratório`, `Recomendação para aplicação real` e `Limitação`.

## Artefatos disponíveis

- [Apresentação PowerPoint](executive-migration-lab.pptx): deck executivo final com 13 slides e notas do apresentador.
- [Gerador da apresentação](generate-executive-migration-lab.mjs): script específico deste deck, mantido para permitir revisão e regeneração do artefato visual.

O Markdown permanece como fonte editorial independente de ferramenta. O gerador requer um ambiente Node.js com `@oai/artifact-tool`; os arquivos intermediários de renderização são gravados em `target/presentation/executive-migration-lab`, enquanto o `.pptx` final substitui o arquivo versionado ao lado desta fonte.

## Distribuição do tempo

| Bloco | Slides | Tempo |
| --- | ---: | ---: |
| Abertura | 1 | 0min30s |
| Parte 1 — Problema, proposta e planejamento | 2–5 | 7min |
| Parte 2 — Provas, correções e aprendizados | 6–10 | 7min30s |
| Parte 3 — Aplicação real e decisão | 11–13 | 5min |
| **Total** | **13** | **20min** |

## Estrutura usada em cada slide

- **Tempo-alvo:** limite editorial para manter a apresentação em 20 minutos.
- **Mensagem central:** a conclusão que deve permanecer para o público.
- **Texto básico:** conteúdo que poderá ser exibido no slide.
- **Notas do apresentador:** contexto oral que não precisa aparecer no slide.

## Slide 1 — Modernizar com controle: do legado ao destino atual

**Tempo-alvo:** 0min30s

**Mensagem central**

`Comprovado no laboratório`: uma aplicação web representativa evoluiu de Java 7 e WildFly 9 para OpenJDK 25, WildFly 41 e Jakarta EE 11 preservando seus contratos funcionais por meio de uma migração incremental e verificável.

**Texto básico**

- Uma aplicação, três fases e uma sequência de estados aprovados.
- O resultado mais reutilizável é o método de migração com evidências.
- A decisão proposta é aplicar esse método primeiro a um piloto controlado.

**Notas do apresentador**

Abrir com a tese e antecipar as três partes: por que o legado exige ação, o que o laboratório comprovou e como iniciar uma aplicação real. Não detalhar bibliotecas neste momento.

# Parte 1 — Problema, proposta e planejamento

## Slide 2 — Problema e risco do legado: compatibilidade não é longevidade

**Tempo-alvo:** 2min

**Mensagem central**

`Recomendação para aplicação real`: manter uma plataforma que inicia não significa manter uma plataforma sustentável; ciclo de vida, compatibilidade e capacidade de atualização precisam ser avaliados em conjunto.

**Texto básico**

- Java 7u80 e WildFly 9 representam um ponto histórico sem fluxo regular de manutenção aprovado.
- Compatibilidade entre Java e WildFly muda por geração e limita saltos diretos.
- Uma versão intermediária pode servir como ponte de engenharia sem ser destino recomendado de produção.
- O destino comunitário atual exige política contínua de atualização; não oferece linha LTS própria.

**Quadro WildFly × Java — referência verificada em 30/07/2026**

| WildFly | Java 7 | Java 8 | Java 11 | Java 17 | Java 21 | Java 25 | Plataforma padrão |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 8–9 | Sim | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7 |
| 10–13 | Não | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7; EE 8 em prévia no 13 |
| 14 | Não | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 8 |
| 15–24 | Não | Sim | Rec. | N/Q | N/Q | N/Q | Java EE 8; Jakarta EE 8 a partir do 17.0.1 |
| 25–26.1 | Não | Sim | Sim | Sim | N/Q | N/Q | Java EE 8 / Jakarta EE 8, APIs `javax.*` |
| 27–29 | Não | Não | Sim | Rec. | N/Q | N/Q | Jakarta EE 10 |
| 30–31 | Não | Não | Sim | Rec. | Aval. | N/Q | Jakarta EE 10 |
| 32 | Não | Não | Sim | Sim | Rec. | N/Q | Jakarta EE 10 |
| 33–34 | Não | Não | Sim | Sim | Rec. | N/Q | Jakarta EE 10 |
| 35–37 | Não | Não | Não | Sim | Rec. | N/Q | Jakarta EE 10 |
| 38–39 | Não | Não | Não | Sim | Rec. | Aval. | Jakarta EE 10 |
| 40–41 | Não | Não | Não | Sim | Sim | Rec. | Jakarta EE 11; variante EE 10 temporária |

**Legenda resumida:** `Sim` = combinação qualificada/documentada; `Rec.` = JDK preferido naquela linha; `Aval.` = funciona, mas ainda estava em avaliação; `N/Q` = não qualificada ou não documentada; `Não` = removida ou abaixo do mínimo; `LTS` = suporte de longo prazo da distribuição Java; `EOL` = fim do ciclo regular de manutenção.

**Notas do apresentador**

Não ler a tabela inteira. Destacar três linhas: WildFly 8–9 como legado, 25–26.1 como ponte compatível com Java 8/11/17 e APIs `javax`, e 40–41 como destino Jakarta EE 11 com Java 25 preferido. Explicar que `Rec.` descreve preferência de runtime, não certificação TCK no mesmo JDK. A matriz é uma fotografia histórica; antes de uma decisão real, versões e suporte devem ser verificados novamente.

## Slide 3 — Proposta do laboratório: transformar incerteza em estados verdes

**Tempo-alvo:** 1min30s

**Mensagem central**

`Comprovado no laboratório`: preservar primeiro o comportamento e mudar poucas dimensões por vez tornou cada incompatibilidade diagnosticável e cada avanço reversível.

**Texto básico**

- Congelar um baseline funcional, reconstruível e auditável antes de modernizar.
- Executar o último estado aprovado no próximo runtime antes de corrigi-lo.
- Separar JVM, servidor, dependências, Jakarta e banco em gates controlados.
- Repetir os mesmos contratos com CI portátil e qualificação no Oracle.
- Encerrar checkpoints com PR, evidência, limitações e rollback.

**Notas do apresentador**

“Estado verde” é uma versão integrada, reconstruível e aprovada pelos critérios daquele ponto. A proposta não é multiplicar ambientes sem necessidade; é separar riscos suficientes para que uma falha tenha causa investigável e um retorno conhecido.

## Slide 4 — Como o laboratório foi construído: Codex, SDD e OpenSpec

**Tempo-alvo:** 2min

**Mensagem central**

`Comprovado no projeto`: planejamento, código, scripts, documentação e evidências foram integralmente construídos com uso do Codex, enquanto especificações, testes e aprovações humanas mantiveram direção e controle.

**Texto básico**

- **Codex:** agente de IA usado para planejar, implementar, diagnosticar, documentar e executar validações.
- **Responsabilidade humana:** definiu objetivos, revisou decisões, forneceu acessos controlados, realizou testes manuais e aprovou checkpoints.
- **SDD:** desenvolvimento orientado por especificações; o comportamento esperado é definido antes de concluir a implementação.
- **OpenSpec:** manteve intenção, decisões, requisitos e tarefas coerentes e versionados.
- **Resultado:** velocidade de execução com rastreabilidade, revisão e evidência reproduzível.

**Fluxo resumido do OpenSpec**

`proposta (por quê) → design (como) → specs (o que deve ser verdade) → tarefas (execução) → evidências/checkpoints`

**Notas do apresentador**

SDD significa *Specification-Driven Development*: a especificação guia a implementação e fornece critérios verificáveis. OpenSpec é a estrutura usada para organizar esse ciclo; não substitui Git, CI ou testes. “Integralmente construído com IA” significa que os artefatos foram produzidos na interação com o Codex, não que a IA decidiu sozinha: direção, credenciais, testes manuais, aceites e responsabilidade permaneceram humanos.

## Slide 5 — Por que dividir o planejamento em três fases

**Tempo-alvo:** 1min30s

**Mensagem central**

`Comprovado no laboratório`: as três fases separaram conhecimento do legado, modernização de baixo impacto e ruptura arquitetural, evitando que todos os riscos aparecessem no mesmo salto.

**Texto básico**

| Fase | Objetivo | Por que existe |
| --- | --- | --- |
| **1 — Baseline legado** | Reproduzir Java 7/WildFly 9 e congelar contratos | Sem estado inicial verificável não é possível distinguir regressão de diferença esperada |
| **2 — Modernização de baixo impacto** | Java 8/WildFly 26 mantendo `javax` | Separa JVM/servidor da ruptura Jakarta e oferece um ponto de estabilização |
| **3 — Destino final** | Dependências modernas, Jakarta EE 11, WildFly 41 e OpenJDK 25 | Concentra as mudanças arquiteturais depois que comportamento e infraestrutura já são conhecidos |

Java 17 e Java 21 foram gates técnicos da fase final: isolaram dependências, Jakarta/WildFly 41 e JVM final sem criar fases públicas adicionais.

**Notas do apresentador**

A fase 1 compra conhecimento; a fase 2 reduz risco operacional sem reescrever namespaces; a fase 3 executa a ruptura necessária com bases mais estáveis. Em uma aplicação real, a ponte pode ser apenas um gate de engenharia se a plataforma intermediária não for adequada para produção.

# Parte 2 — Constatações, correções e lições aprendidas

## Slide 6 — Constatações efetivamente comprovadas

**Tempo-alvo:** 1min30s

**Mensagem central**

`Comprovado no laboratório`: a aplicação preservou o comportamento essencial até o destino final e foi qualificada por trilhas independentes, com limites explicitamente registrados.

**Texto básico**

- Os 14 contratos do baseline permaneceram válidos durante a evolução.
- O destino Jakarta acrescentou proteção de fragmentos web e encerrou com 15/15 cenários.
- O mesmo WAR final foi executado em OpenJDK 21 e 25.
- A trilha portátil usou H2; a qualificação oficial usou Oracle 19c RU 19.3.
- A reprodução final partiu de checkout limpo e auditou WAR, dependências, versões, origens, checksums e rollback.

**O que isso não significa**

`Limitação`: 15/15 comprova todos os cenários definidos para o laboratório, não cobertura total de uma aplicação real. H2 acelera feedback, mas não substitui Oracle. Carga, cluster, failover, integrações não modeladas e requisitos próprios de produção exigem gates adicionais.

**Notas do apresentador**

Separar claramente velocidade de feedback e qualificação oficial. O valor da prova está em saber exatamente qual comportamento foi exercitado, em qual runtime, com qual artefato e qual banco — e também o que permaneceu fora do escopo.

## Slide 7 — Incompatibilidades e correções: não foi apenas trocar versões

**Tempo-alvo:** 1min30s

**Mensagem central**

`Comprovado no laboratório`: 27 incompatibilidades alcançaram ambiente, build, código, namespace, servidor, classloader, configuração, XML e banco; cada correção foi ligada à falha anterior e a uma prova posterior.

**Texto básico**

- **Capturar:** tentar o último estado verde no próximo runtime e registrar a falha natural.
- **Classificar:** separar toolchain, deployment, dependência, segurança, configuração e persistência.
- **Corrigir:** preservar o contrato da aplicação, não necessariamente a biblioteca antiga.
- **Provar:** repetir contratos e auditar o artefato realmente implantado.
- **Documentar:** registrar causa, decisão, evidência, limitação e rollback.

**Notas do apresentador**

A quantidade é menos importante que a variedade. Um salto direto poderia apresentar um único deployment quebrado escondendo causas diferentes. O catálogo permite reaproveitar sinais e estratégias durante o inventário de outra aplicação.

## Slide 8 — Decisões de plataforma e infraestrutura

**Tempo-alvo:** 1min30s

**Mensagem central**

`Comprovado no laboratório`: runtime e configuração também são parte da entrega; as decisões de plataforma foram versionadas, auditadas e qualificadas por fase.

**Texto básico**

| Componente | Origem | Decisão | Destino e justificativa |
| --- | --- | --- | --- |
| Java | Oracle JDK 7u80 | Evoluir por gates 8, 17 e 21; qualificar a JVM final isoladamente | Temurin OpenJDK 25; build final com `--release 21` para separar JDK de build e APIs-alvo |
| Maven | 3.8.9 no legado | Fixar a última versão escolhida para o Java 7 e atualizar somente após estabilizar a ponte | Maven 3.9.16; Maven 4 RC foi evitado para manter ferramenta estável |
| WildFly | 9.0.2 | Usar 26.1.3 como ponte `javax` e 41 após o gate Jakarta | WildFly Community 41; runtime final open source, com atualização contínua necessária |
| Plataforma web | Java EE 7, Servlet 2.4/JSP 2.0/JSTL 1.2 | Preservar `javax` na fase 2 e migrar descritores, APIs e templates em gate próprio | Jakarta EE Web Profile 11 em escopo `provided` |
| H2 | 1.4.200 | Manter apenas como feedback portátil e atualizar conforme o gate | H2 2.4.240 em memória; nunca substitui qualificação Oracle |
| Oracle | Database 19c | Manter como banco oficial e usar schema descartável autorizado | Oracle 19c RU 19.3 observado na qualificação; segredos e driver permanecem externos |
| Datasource/JNDI | Pool do WildFly e `java:/jdbc/MigrationDS` | Preservar a fronteira da aplicação e reprovisionar por runtime | Mesmo JNDI, pool controlado pelo servidor e teste de conexão em cada gate |

**Notas do apresentador**

Destacar Java, WildFly e Oracle; as demais linhas ficam para consulta. A decisão mais importante foi não colocar seleção de banco ou pool dentro do código da aplicação. O JNDI permaneceu estável enquanto driver, módulo e servidor evoluíram.

## Slide 9 — Decisões de bibliotecas e APIs

**Tempo-alvo:** 2min

**Mensagem central**

`Comprovado no laboratório`: bibliotecas foram atualizadas quando mantidas, removidas quando duplicavam a plataforma e substituídas pelo contrato funcional quando estavam abandonadas ou incompatíveis com Jakarta.

**Texto básico**

| Componente legado | Decisão | Destino / contrato preservado |
| --- | --- | --- |
| MyBatis 3.4.5 | Atualizar sem trocar o modelo de persistência | MyBatis 3.5.19, mesmos mapeamentos e `logImpl=SLF4J` |
| Log4j 1.2.14 | Remover biblioteca e configuração interna ao WAR | SLF4J integrado ao JBoss LogManager, preservando categorias, correlação e exceção completa |
| Commons FileUpload 1.2.2 | Atualização transitória na fase `javax`; remoção no destino | Multipart nativo por `@MultipartConfig` e Servlet `Part`, preservando limites e metadados |
| Reflections 0.9.10 | Atualizar temporariamente; depois substituir o único contrato usado | `ServletContainerInitializer` + `@HandlesTypes` + fachada para descoberta de validators |
| Tiles 2.1.4 | Remover por ausência de caminho Jakarta adequado | JSP tag files/includes protegidos, preservando cabeçalho, conteúdo e rodapé |
| XMLBeans 2.3.0 | Atualizar e tornar a geração de fontes reproduzível | XMLBeans 5.3.0 com tipos regenerados a partir do XSD |
| dom4j 1.6.1 | Atualizar e endurecer o parsing | dom4j 2.2.0 com rejeição de XXE/entidades externas |
| `xml-apis` 1.3.02 | Remover API duplicada | APIs fornecidas pelo módulo `java.xml` do JDK |
| Geronimo StAX 1.0 | Remover API duplicada | StAX fornecido pelo módulo `java.xml` do JDK |
| `ojdbc7` | Substituir e manter fora do WAR | `ojdbc17` 23.26.2.0.0 provisionado como módulo do WildFly |
| Servlet/JSP/JSTL `javax` | Migrar somente no gate Jakarta | APIs Jakarta fornecidas pelo WildFly; JSTL Jakarta compatível |
| TLD/taglib 2.0 | Preservar evidência histórica e migrar schema/handler | TLD 3.0 e tag handler Jakarta |

**Notas do apresentador**

Não ler as doze linhas. Destacar quatro padrões de decisão: atualizar componente mantido; remover API já fornecida; substituir biblioteca abandonada pelo contrato; manter driver e APIs do servidor fora do WAR. Usar FileUpload, Reflections e Log4j como exemplos representativos.

## Slide 10 — Lições aprendidas: controles que permanecem válidos

**Tempo-alvo:** 1min

**Mensagem central**

`Recomendação para aplicação real`: versões e quantidade de gates podem mudar; os controles de conhecimento, evidência e retorno não deveriam mudar.

**Texto básico**

- **Baseline primeiro:** código, artefato, configuração e comportamento formam a primeira entrega.
- **Uma dimensão por vez:** gates menores preservam diagnóstico e revisão.
- **Provar o executável:** contratos externos e auditoria do WAR valem mais que “compilou”.
- **Feedback não é qualificação:** H2 acelera; Oracle decide persistência oficial.
- **Evidência e rollback duráveis:** aprovação deve sobreviver a branches, squash e mudança de ambiente.

**Notas do apresentador**

O valor do laboratório não é recomendar versões históricas. É demonstrar uma disciplina: saber de onde se partiu, alterar riscos de forma isolada, provar o artefato real e manter uma opção de retorno.

# Parte 3 — Aplicação em uma migração real

## Slide 11 — Como aplicar o método em uma aplicação real

**Tempo-alvo:** 2min

**Mensagem central**

`Recomendação para aplicação real`: iniciar por uma aplicação piloto e financiar primeiro conhecimento verificável — inventário e baseline — antes de assumir destino, cronograma ou janela de produção.

**Texto básico**

1. **Enquadrar:** selecionar piloto e responsáveis de negócio, aplicação, plataforma, DBA e segurança.
2. **Inventariar:** artefato, runtime, dependências, configurações, dados, integrações e requisitos operacionais.
3. **Construir o baseline:** reproduzir o legado e congelar contratos dos fluxos críticos no banco oficial.
4. **Desenhar gates:** separar JVM, servidor, dependências, Jakarta e riscos específicos encontrados.
5. **Qualificar e implantar:** executar trilha portátil, banco oficial, segurança, observabilidade, ensaio de corte e rollback.

**Notas do apresentador**

O primeiro compromisso não é migrar tudo: é produzir um diagnóstico confiável. Só depois do baseline a equipe consegue propor versões, número de gates, esforço, riscos residuais e alternativas de destino.

## Slide 12 — Roadmap, gates e limites da aplicação real

**Tempo-alvo:** 1min30s

**Mensagem central**

`Recomendação para aplicação real`: promover somente quando cada gate tiver artefato imutável, comportamento aprovado, ambiente identificado, risco residual aceito e retorno ensaiado.

**Texto básico**

| Gate | Entrega mínima para decisão |
| --- | --- |
| Inventário | escopo, responsáveis, dependências, integrações, EOL/licenças e riscos classificados |
| Baseline | WAR/checksum, runtime/configuração, contratos e qualificação no banco oficial |
| Ponte de baixo impacto | JVM e servidor isolados, mesmos contratos e plano explícito de saída |
| Dependências/Jakarta | bibliotecas decididas, namespace migrado, WAR auditado e segurança validada |
| JVM final | toolchain, bytecode, agentes, desempenho e mesmo WAR qualificado |
| Corte | Blue/Green, go/no-go, observabilidade, proteção de dados e rollback cronometrado |

`Limitação`: carga, cluster, failover, segurança específica, EAR/EJB/JMS, integrações externas, SQL proprietário e requisitos não modelados precisam de gates próprios. O laboratório não fornece automaticamente prazo, orçamento ou certificação de produção.

**Notas do apresentador**

Mostrar que gate é uma decisão, não apenas uma etapa técnica. Se a aplicação real usa recursos ausentes no laboratório, o roteiro ganha novos gates; não se força a aplicação a caber no exemplo.

## Slide 13 — Próximos passos e decisão solicitada à liderança

**Tempo-alvo:** 1min30s

**Mensagem central**

`Recomendação para aplicação real`: autorizar uma etapa limitada de enquadramento e baseline para converter incerteza em evidência antes de decidir pela execução completa da migração.

**Texto básico**

- Selecionar uma aplicação piloto com relevância e escopo administrável.
- Nomear patrocinador e responsáveis multidisciplinares pelas decisões.
- Autorizar inventário, ambiente isolado, acesso controlado ao banco e construção do baseline.
- Definir critérios de sucesso, riscos que exigem escalonamento e formato das evidências.
- Retornar à liderança com diagnóstico, alternativas, roadmap, estimativa e recomendação de continuidade.

**Primeira entrega esperada**

Inventário revisado + baseline reproduzível + mapa de riscos e incompatibilidades + opções de destino e gates, sem compromisso prematuro com corte em produção.

**Notas do apresentador**

Fechar com uma decisão objetiva: aprovar descoberta e baseline do piloto, não uma migração cega. Prazo, custo e plano final serão apresentados depois dessa evidência, com alternativas e critérios de go/no-go.

# Referências editoriais — fora dos slides

Esta seção preserva a rastreabilidade das afirmações e não faz parte do conteúdo a ser exibido na apresentação.

## Slide 1

- [Conclusão do projeto — propósito e conclusão](../project-conclusion.md): objetivo, plataforma inicial/final e tese dos estados verdes.
- [Relatório consolidado CP-3K](../evidence/CP-3K.md): aprovação do destino final e das três fases públicas.

## Slide 2

- [Evolução WildFly × Java SE](../wildfly-java-compatibility.md): matriz completa, notas, ciclos de manutenção e fontes primárias.
- [Conclusão do projeto — lições 1 e 2](../project-conclusion.md): risco de modernizar sem baseline e de misturar variáveis.

## Slide 3

- [Conclusão do projeto — propósito e planejamento](../project-conclusion.md): princípios incrementais e gates utilizados.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): checkpoints, evidência antes/depois e dupla qualificação.
- [Checkpoints do laboratório](../checkpoints.md): entregas mínimas e tags públicas.

## Slide 4

- [Codex handoff](../codex-handoff.md): registro versionado das decisões e do trabalho conduzido com o agente.
- [Change arquivada do laboratório](../../openspec/changes/archive/2026-08-07-create-java-web-migration-lab/): proposal, design, specs e 110 tarefas concluídas.
- [Specs principais](../../openspec/specs/): contratos normativos sincronizados após o fechamento.
- [Fluxo GitHub](../github-workflow.md): revisão, CI, PRs e checkpoints usados nas aprovações.

## Slide 5

- [Conclusão do projeto — planejamento executado](../project-conclusion.md): objetivos e plataformas aprovadas nas três fases.
- [Relatório CP-3K — três fases públicas](../evidence/CP-3K.md): entradas, runtimes e saídas aprovadas.
- [Checkpoints do laboratório](../checkpoints.md): decomposição das fases em entregas incrementais.

## Slide 6

- [Relatório CP-3K — checkpoints, ambientes e limitações](../evidence/CP-3K.md): resultados `portable-ci` e `oracle-qualified`.
- [Reprodução final em H2](../../migration/evidence/CP-3K/reproduction-ci-h2.json): execução portátil a partir de checkout limpo.
- [Reprodução final em Oracle](../../migration/evidence/CP-3K/reproduction-oracle.json): qualificação oficial no Oracle 19c.
- [Fechamento CP-3K](../../migration/evidence/CP-3K/closure.properties): contratos, WAR, auditoria e resultado final.

## Slide 7

- [Catálogo de incompatibilidades](../../migration/incompatibility-catalog.md): visão humana das 27 falhas, causas, correções e provas.
- [Índice estruturado](../../migration/incompatibilities.tsv): fonte canônica validada pelo CI.
- [Conclusão do projeto — lições 3, 6, 7 e 8](../project-conclusion.md): falha antes da correção, WAR, contratos e Jakarta.

## Slide 8

- [Relatório CP-3K — três fases e ambientes](../evidence/CP-3K.md): versões e papéis dos runtimes.
- [Preparação do ambiente](../environment-setup.md): origens, licenças e versões fixadas.
- [Spec WildFly/Oracle](../../openspec/specs/wildfly-oracle-runtime/spec.md): runtime, JNDI, driver e dupla qualificação.
- [Evolução WildFly × Java](../wildfly-java-compatibility.md): compatibilidade e manutenção comunitária.

## Slide 9

- [Conclusão do projeto — resultado e substituições](../project-conclusion.md): versões finais e contratos preservados.
- [Relatório CP-3K — incompatibilidades resolvidas](../evidence/CP-3K.md): transições aprovadas.
- [Catálogo de incompatibilidades](../../migration/incompatibility-catalog.md): registros detalhados de falha/correção.
- [Spec da aplicação Jakarta](../../openspec/specs/modern-jakarta-webapp/spec.md): dependências proibidas e mecanismos finais.

## Slide 10

- [Conclusão do projeto — doze lições aprendidas](../project-conclusion.md): fundamento completo dos cinco controles resumidos.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): contratos, auditoria, fixtures, evidência e dupla qualificação.

## Slide 11

- [Conclusão do projeto — aplicação em sistema real](../project-conclusion.md): etapas de inventário até implantação.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): papéis, janela, go/no-go e rollback.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): critérios reutilizáveis de gates e evidência.

## Slide 12

- [Conclusão do projeto — critérios por gate](../project-conclusion.md): condições recomendadas de aprovação.
- [Roteiro para aplicação real](../phase2-real-application-migration-runbook.md): implantação paralela, janela e rollback.
- [Relatório CP-3K — limitações](../evidence/CP-3K.md): itens não qualificados pelo laboratório.

## Slide 13

- [Conclusão do projeto — critérios recomendados e aplicação real](../project-conclusion.md): primeira entrega e condições mínimas.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): responsabilidades e preparação.
- [Checkpoints do laboratório](../checkpoints.md): referência para entregas pequenas e rastreáveis.
