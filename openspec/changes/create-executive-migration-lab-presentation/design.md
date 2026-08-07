## Context

O projeto já possui documentação técnica, evidências por checkpoint, catálogo de incompatibilidades e uma conclusão consolidada. Esse material foi escrito para reprodução e auditoria, não para uma conversa executiva de 15 a 20 minutos. Gerentes e diretores precisam entender por que o laboratório reduz risco, o que foi efetivamente comprovado, quais limites permanecem e qual decisão ou patrocínio é necessário para aplicar o método a uma aplicação real.

A apresentação será criada primeiro como conteúdo estruturado em Markdown. O documento será a fonte editorial para uma futura conversão em PowerPoint, Google Slides ou outra ferramenta, sem vincular esta change a um formato visual.

## Goals / Non-Goals

**Goals:**

- produzir uma narrativa executiva coerente com aproximadamente 10 a 12 slides;
- fornecer título, mensagem central, texto básico, evidências e notas breves para cada slide;
- explicar o planejamento de três fases e os gates técnicos sem exigir conhecimento prévio de Java ou WildFly;
- apresentar resultados comprovados, limitações e lições aprendidas sem transformar inferências em fatos;
- terminar com uma proposta de aplicação em uma migração real e decisões esperadas da liderança;
- manter rastreabilidade entre afirmações importantes e documentos/evidências do repositório.

**Non-Goals:**

- criar o arquivo visual final, template corporativo, imagens, animações ou gráficos definitivos;
- preparar uma apresentação técnica detalhada para desenvolvedores ou operadores;
- afirmar que o laboratório qualifica automaticamente qualquer aplicação real;
- estimar orçamento, prazo ou equipe de uma aplicação real sem inventário e baseline próprios;
- alterar código, runtime, CI, banco de dados ou resultados já aprovados no laboratório.

## Decisions

### 1. Usar uma narrativa executiva de 12 slides

A sequência será:

1. título e tese executiva;
2. problema e risco de permanecer no legado;
3. proposta do laboratório e princípio da migração incremental;
4. planejamento em três fases;
5. método de checkpoints, evidências e rollback;
6. evolução tecnológica alcançada;
7. constatações comprovadas pelos testes;
8. incompatibilidades representativas e como foram tratadas;
9. principais lições aprendidas;
10. limites do laboratório e riscos ainda dependentes da aplicação real;
11. roteiro para aplicar o método em uma migração real;
12. próximos passos e decisões solicitadas à liderança.

Doze slides permitem manter a progressão problema → proposta → prova → aplicação → decisão. A alternativa de condensar tudo em seis ou sete slides foi rejeitada porque misturaria evidências, limitações e recomendações; uma apresentação técnica mais longa também foi rejeitada por não corresponder ao público-alvo.

### 2. Manter uma estrutura textual uniforme por slide

Cada slide terá os campos `Mensagem central`, `Texto básico`, `Evidências` e `Notas do apresentador`. O texto básico terá preferencialmente três a cinco pontos curtos; detalhes técnicos e explicações ficarão nas notas.

A alternativa de redigir apenas títulos e bullets foi rejeitada porque deixaria a interpretação dependente demais do apresentador. Um roteiro integral, palavra por palavra, também foi rejeitado por dificultar adaptação ao tempo e ao contexto da reunião.

### 3. Separar prova, recomendação e limitação

Afirmações serão classificadas pela forma como aparecem no texto:

- `Comprovado no laboratório`: resultado sustentado por contratos, build, deployment, auditoria ou qualificação registrada;
- `Recomendação para aplicação real`: prática derivada do experimento, que ainda exige adaptação e validação local;
- `Limitação`: aspecto não coberto ou não generalizável pelo laboratório.

Essa separação evita apresentar o sucesso do laboratório como garantia de prazo ou compatibilidade para outra aplicação.

### 4. Usar o repositório como fonte de verdade

Números, versões e resultados devem apontar para fontes como `docs/project-conclusion.md`, `docs/evidence/CP-3K.md`, `docs/checkpoints.md`, `migration/incompatibility-catalog.md` e as specs principais. Links ficarão no campo de evidências de cada slide, podendo ser removidos do material visual futuro sem serem perdidos na fonte editorial.

### 5. Traduzir tecnologia em impacto gerencial

Termos como EOL, baseline, gate, rollback, H2, Oracle, Java e WildFly serão associados a risco, continuidade, auditabilidade, velocidade de feedback ou segurança operacional. Versões técnicas serão usadas somente quando demonstrarem o tamanho da evolução ou sustentarem uma decisão.

## Risks / Trade-offs

- [Excesso de conteúdo técnico] → limitar o texto visível e deslocar detalhes para notas e evidências.
- [Simplificação esconder limitações] → dedicar um slide específico aos limites e identificar recomendações como recomendações.
- [Números divergirem da evidência] → revisar todas as afirmações quantitativas contra as fontes versionadas.
- [Apresentação parecer uma estimativa para produção] → declarar que prazo, custo e quantidade de gates dependem do inventário da aplicação real.
- [Conteúdo envelhecer com novas versões] → tratar versões como resultado histórico do laboratório, com data e fontes, não como recomendação permanente de produto.
- [Próximos passos genéricos] → encerrar com decisões concretas: selecionar aplicação piloto, nomear responsáveis e autorizar inventário/baseline.

