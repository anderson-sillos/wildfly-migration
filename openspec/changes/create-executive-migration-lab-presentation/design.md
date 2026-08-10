## Context

O projeto já possui documentação técnica, evidências por checkpoint, catálogo de incompatibilidades e uma conclusão consolidada. Esse material foi escrito para reprodução e auditoria, não para uma conversa executiva de até 20 minutos. Gerentes e diretores precisam entender o risco do legado, por que o laboratório foi dividido em três fases, o que foi efetivamente comprovado e qual decisão permite aplicar o método a uma aplicação real.

O laboratório foi integralmente construído com uso de IA por meio do Codex: planejamento, código, scripts, documentação e organização das evidências foram produzidos na interação com o agente, sob direção, revisão, testes e aprovações humanas. O trabalho seguiu SDD (*Specification-Driven Development*) com OpenSpec para manter proposta, design, requisitos, tarefas e implementação rastreáveis.

A apresentação será criada primeiro como conteúdo estruturado em Markdown. O documento será a fonte editorial para uma futura conversão em PowerPoint, Google Slides ou outra ferramenta, sem vincular esta change a um formato visual.

## Goals / Non-Goals

**Goals:**

- organizar a apresentação em três grandes partes com duração total máxima de 20 minutos;
- fornecer título, tempo-alvo, mensagem central, texto básico, evidências e notas breves para cada slide;
- incluir o quadro WildFly × Java e associá-lo ao risco de ciclo de vida e compatibilidade;
- explicar como Codex, SDD e OpenSpec estruturaram a construção do laboratório;
- justificar as três fases como mecanismo de separação de riscos;
- apresentar comprovações, incompatibilidades e decisões por componente/biblioteca;
- transformar as lições em um roteiro de aplicação real e uma decisão executiva;
- manter rastreabilidade entre afirmações importantes e documentos/evidências do repositório.

**Non-Goals:**

- criar o arquivo visual final, template corporativo, imagens, animações ou gráficos definitivos;
- preparar uma apresentação técnica detalhada para desenvolvedores ou operadores;
- afirmar que IA substituiu direção, revisão, testes ou aprovação humana;
- ensinar todos os recursos do Codex, SDD ou OpenSpec;
- afirmar que o laboratório qualifica automaticamente qualquer aplicação real;
- estimar orçamento, prazo ou equipe de uma aplicação real sem inventário e baseline próprios;
- alterar código, runtime, CI, banco de dados ou resultados já aprovados no laboratório.

## Decisions

### 1. Organizar 13 slides em três partes e 20 minutos

| Parte | Slide | Assunto | Tempo |
| --- | ---: | --- | ---: |
| Abertura | 1 | Tese executiva | 0min30s |
| 1 — Problema e proposta | 2 | Risco do legado e quadro WildFly × Java | 2min |
| 1 — Problema e proposta | 3 | Proposta do laboratório e estados verdes | 1min30s |
| 1 — Problema e proposta | 4 | Construção com Codex, SDD e OpenSpec | 2min |
| 1 — Problema e proposta | 5 | Planejamento em três fases e sua justificativa | 1min30s |
| 2 — Provas e aprendizados | 6 | Constatações comprovadas | 1min30s |
| 2 — Provas e aprendizados | 7 | Incompatibilidades e princípio das correções | 1min30s |
| 2 — Provas e aprendizados | 8 | Decisões de plataforma e infraestrutura | 1min30s |
| 2 — Provas e aprendizados | 9 | Decisões de bibliotecas e APIs | 2min |
| 2 — Provas e aprendizados | 10 | Lições aprendidas | 1min |
| 3 — Aplicação real | 11 | Como aplicar o método | 2min |
| 3 — Aplicação real | 12 | Roadmap, gates e limites | 1min30s |
| 3 — Aplicação real | 13 | Próximos passos e decisão da liderança | 1min30s |
|  |  | **Total** | **20min** |

As partes 1 e 2 recebem 7min30s cada; a parte 3 recebe 5min. A quantidade de slides deixa de ser um requisito fixo: o controle passa a ser o tempo e a cobertura da narrativa. A alternativa de manter 12 slides foi rejeitada porque condensaria o processo Codex/SDD/OpenSpec ou a tabela de decisões por biblioteca.

### 2. Usar divisões editoriais, não slides adicionais de seção

O Markdown terá títulos `Parte 1`, `Parte 2` e `Parte 3` envolvendo os slides correspondentes. As divisões não consomem tempo nem exigem páginas visuais próprias. Isso torna as três grandes partes explícitas sem aumentar a duração.

### 3. Manter uma estrutura textual uniforme por slide

Cada slide terá os campos `Tempo-alvo`, `Mensagem central`, `Texto básico`, `Evidências` e `Notas do apresentador`. Tabelas serão usadas quando a relação entre versões, componentes e decisões for mais clara que uma lista. Detalhes técnicos e explicações ficarão nas notas.

A alternativa de redigir apenas títulos e bullets foi rejeitada porque deixaria a interpretação dependente demais do apresentador. Um roteiro integral, palavra por palavra, também foi rejeitado por dificultar adaptação à reunião.

### 4. Apresentar o quadro WildFly × Java com leitura orientada

O slide de risco incluirá a matriz de compatibilidade versionada no projeto. As notas orientarão o apresentador a destacar apenas as linhas relevantes à jornada — WildFly 8–9, 25–26.1 e 40–41 — e explicar EOL, LTS, `Sim`, `Rec.` e `N/Q`. O quadro completo permanece disponível para auditoria, mas não deve ser lido célula por célula.

### 5. Explicar Codex, SDD e OpenSpec como processo de governança

A apresentação registrará que todo o laboratório foi construído com uso do Codex, mantendo a responsabilidade humana pelas decisões e aprovações. SDD será descrito como desenvolver a partir de uma especificação verificável. OpenSpec será resumido no fluxo:

`proposta (por quê) → design (como) → specs (o que deve ser verdade) → tarefas (execução) → evidências/checkpoints`.

O objetivo é demonstrar rastreabilidade e velocidade com controle, não promover uma ferramenta ou alegar autonomia irrestrita da IA.

### 6. Separar decisões de plataforma das decisões de bibliotecas

A Parte 2 usará duas tabelas:

- plataforma/infraestrutura: Java, Maven, WildFly, Java EE/Jakarta EE, H2, Oracle e datasource/JDBC;
- bibliotecas/APIs: MyBatis, Log4j, Commons FileUpload, Reflections, Tiles, XMLBeans, dom4j, APIs XML duplicadas, APIs web/TLD e driver Oracle.

Cada linha mostrará origem, decisão e destino/justificativa. Essa separação evita uma tabela única ilegível e atende à necessidade de listar os componentes relevantes.

### 7. Separar prova, recomendação e limitação

Afirmações serão classificadas pela forma como aparecem no texto:

- `Comprovado no laboratório`: resultado sustentado por contratos, build, deployment, auditoria ou qualificação registrada;
- `Recomendação para aplicação real`: prática derivada do experimento, que ainda exige adaptação e validação local;
- `Limitação`: aspecto não coberto ou não generalizável pelo laboratório.

Essa separação evita apresentar o sucesso do laboratório, ou o uso de IA, como garantia de prazo, custo ou compatibilidade para outra aplicação.

### 8. Usar o repositório como fonte de verdade

Números, versões e resultados devem apontar para fontes como `docs/project-conclusion.md`, `docs/evidence/CP-3K.md`, `docs/wildfly-java-compatibility.md`, `docs/codex-handoff.md`, os artefatos OpenSpec e `migration/incompatibility-catalog.md`. Links ficarão no campo de evidências de cada slide.

## Risks / Trade-offs

- [Quadro de compatibilidade denso] → orientar a leitura para três linhas e manter a legenda nas notas.
- [Tabela de bibliotecas extensa] → separar plataforma de bibliotecas e limitar a fala às decisões mais representativas.
- [Uso de IA parecer ausência de governança] → explicitar direção, revisão, testes e aprovação humana.
- [OpenSpec virar explicação de ferramenta] → limitar a apresentação ao fluxo conceitual e ao valor de rastreabilidade.
- [Excesso de conteúdo técnico] → controlar tempo por slide e deslocar detalhes para notas/evidências.
- [Simplificação esconder limitações] → incorporar limites ao roadmap real e identificar recomendações como recomendações.
- [Números divergirem da evidência] → revisar todas as afirmações quantitativas contra fontes versionadas.
- [Apresentação parecer uma estimativa para produção] → declarar que prazo, custo e quantidade de gates dependem do inventário da aplicação real.

## Plano de reorganização

1. Reordenar o documento em três partes e 13 slides.
2. Incorporar o quadro de compatibilidade e sua leitura executiva.
3. Criar o slide Codex/SDD/OpenSpec.
4. Consolidar comprovações, incompatibilidades e duas tabelas de decisões.
5. Reescrever aplicação real e decisão executiva.
6. Executar revisão factual, editorial, temporal e de links antes do fechamento.
