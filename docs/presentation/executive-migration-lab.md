# Modernização com controle — apresentação executiva do laboratório

## Orientação editorial

- **Público:** gerentes e diretores responsáveis por aplicações, tecnologia, operações, segurança, dados e continuidade.
- **Objetivo:** apresentar a proposta do laboratório, o planejamento executado, as constatações comprovadas, as lições aprendidas e um caminho para aplicar o método a uma migração real.
- **Duração planejada:** 15 a 20 minutos, reservando perguntas para depois do slide 12.
- **Escopo desta versão:** organização e conteúdo textual; layout, identidade visual, imagens, animações e ferramenta de apresentação serão definidos posteriormente.
- **Princípio de comunicação:** diferenciar `Comprovado no laboratório`, `Recomendação para aplicação real` e `Limitação`.

## Estrutura usada em cada slide

- **Mensagem central:** a conclusão que deve permanecer para o público.
- **Texto básico:** conteúdo curto que poderá ser exibido no slide.
- **Evidências:** fontes versionadas que sustentam afirmações e números.
- **Notas do apresentador:** contexto oral que não precisa aparecer no slide.

## Slide 1 — Modernizar com controle: do legado ao destino atual

**Mensagem central**

`Comprovado no laboratório`: uma aplicação web representativa evoluiu de Java 7 e WildFly 9 para OpenJDK 25, WildFly 41 e Jakarta EE 11 preservando seus contratos funcionais por meio de uma migração incremental e verificável.

**Texto básico**

- Uma única aplicação: do baseline legado ao destino moderno, sem criar uma reescrita paralela.
- Três fases públicas, com gates técnicos entre elas para isolar riscos.
- Contratos funcionais, persistência, empacotamento e runtime validados ao longo da evolução.
- O principal resultado é o método reproduzível, não apenas a atualização das versões.

**Evidências**

- [Conclusão do projeto — propósito e conclusão](../project-conclusion.md): objetivo, plataforma inicial/final e tese dos estados verdes.
- [Relatório consolidado CP-3K](../evidence/CP-3K.md): aprovação do destino final e das três fases públicas.

**Notas do apresentador**

Abrir com a tese, sem detalhar bibliotecas. O laboratório não afirma que toda aplicação Java 7 seguirá o mesmo caminho sem adaptações; ele demonstra que é possível transformar uma modernização ampla em decisões menores, comprováveis e reversíveis. Antecipar que a apresentação mostrará o planejamento, as provas, as limitações e a forma recomendada de iniciar uma aplicação real.

## Slide 2 — O problema: risco crescente e mudança difícil de provar

**Mensagem central**

`Recomendação para aplicação real`: tratar o legado apenas como uma lista de versões antigas subestima o risco; sem baseline e evidências, a organização não consegue provar que uma mudança preservou o comportamento necessário ao negócio.

**Texto básico**

- O ponto de partida usa componentes fora do ciclo de vida, reduzindo opções de suporte e correção.
- Artefato, configuração, dependências e comportamento real podem divergir do conhecimento documentado.
- Um salto direto mistura problemas de Java, servidor, bibliotecas, banco e configuração.
- Sem contratos objetivos, “compilou” ou “subiu” não significa que a aplicação continua correta.
- Sem estados intermediários verdes, diagnóstico e rollback ficam mais lentos e arriscados.

**Evidências**

- [Evolução WildFly × Java SE](../wildfly-java-compatibility.md): ciclo de vida e compatibilidade das plataformas envolvidas.
- [Conclusão do projeto — lições 1 e 2](../project-conclusion.md): risco de modernizar sem baseline e de misturar variáveis.
- [Spec do baseline legado](../../openspec/specs/legacy-webapp-baseline/spec.md): ambiente, contratos e manifesto exigidos para o estado inicial.

**Notas do apresentador**

Traduzir “baseline” como o estado inicial conhecido e reproduzível: código, artefato, configuração e comportamentos críticos registrados. O laboratório não mediu impacto financeiro, incidentes ou exposição de uma aplicação real; esses dados dependem de inventário próprio. O ponto comprovado é que misturar muitas mudanças ao mesmo tempo reduz a capacidade de localizar a causa de uma falha.

## Slide 3 — A proposta: uma sequência de estados verdes

**Mensagem central**

`Comprovado no laboratório`: preservar primeiro o comportamento e mudar poucas dimensões por vez tornou cada incompatibilidade diagnosticável. `Recomendação para aplicação real`: adaptar essa disciplina ao contexto, aos riscos e aos controles da organização.

**Texto básico**

- Congelar primeiro um baseline funcional, reconstruível e auditável.
- Alterar JVM, servidor, dependências e namespace em passos controlados.
- Executar o último estado verde no próximo runtime antes de aplicar correções.
- Repetir os mesmos contratos com feedback portátil e qualificação no banco oficial.
- Encerrar cada checkpoint com evidência, aprovação e caminho de retorno.

**Evidências**

- [Conclusão do projeto — propósito e planejamento](../project-conclusion.md): princípios incrementais e gates utilizados.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): checkpoints, evidência antes/depois e dupla qualificação.
- [Checkpoints do laboratório](../checkpoints.md): entregas mínimas e tags públicas.

**Notas do apresentador**

“Estado verde” é uma versão integrada que pode ser reconstruída e que passou pelos critérios definidos para aquele ponto da migração. O H2 ofereceu feedback rápido no CI remoto, enquanto o Oracle permaneceu como qualificação oficial de persistência. O método aceita que versões e quantidade de gates mudem em outra aplicação; o que deve permanecer é a separação de variáveis, a evidência e o rollback.

## Slide 4 — O planejamento: três fases, uma única aplicação

**Mensagem central**

_A redigir na tarefa 2.2._

**Texto básico**

_A redigir na tarefa 2.2._

**Evidências**

- [Conclusão do projeto — planejamento executado](../project-conclusion.md): objetivos e plataformas aprovadas nas três fases.
- [Relatório CP-3K — três fases públicas](../evidence/CP-3K.md): entradas, runtimes e saídas aprovadas.
- [Checkpoints do laboratório](../checkpoints.md): decomposição das fases em entregas incrementais.

**Notas do apresentador**

_A redigir na tarefa 2.2._

## Slide 5 — Como reduzimos o risco: checkpoints, evidência e rollback

**Mensagem central**

_A redigir na tarefa 2.2._

**Texto básico**

_A redigir na tarefa 2.2._

**Evidências**

- [Checkpoints do laboratório](../checkpoints.md): conteúdo mínimo de cada entrega e registros de rollback.
- [Fluxo GitHub](../github-workflow.md): branches, pull requests e gates de integração.
- [Conclusão do projeto — lições 3, 10 e 12](../project-conclusion.md): falha antes da correção, evidência durável e checkpoints pequenos.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): requisitos normativos de evidência, fechamento e retorno ao estado verde.

**Notas do apresentador**

_A redigir na tarefa 2.2._

## Slide 6 — A evolução alcançada

**Mensagem central**

_A redigir na tarefa 2.3._

**Texto básico**

_A redigir na tarefa 2.3._

**Evidências**

- [Relatório CP-3K — três fases públicas](../evidence/CP-3K.md): versões e contratos aprovados em cada destino.
- [Conclusão do projeto — resultado técnico](../project-conclusion.md): stack final e bibliotecas substituídas.
- [Spec da aplicação Jakarta moderna](../../openspec/specs/modern-jakarta-webapp/spec.md): requisitos do runtime final e da equivalência funcional.

**Notas do apresentador**

_A redigir na tarefa 2.3._

## Slide 7 — O que foi efetivamente comprovado

**Mensagem central**

_A redigir na tarefa 2.3._

**Texto básico**

_A redigir na tarefa 2.3._

**Evidências**

- [Relatório CP-3K — checkpoints e ambientes](../evidence/CP-3K.md): resultados `portable-ci` e `oracle-qualified`.
- [Reprodução final em H2](../../migration/evidence/CP-3K/reproduction-ci-h2.json): execução portátil a partir de checkout limpo.
- [Reprodução final em Oracle](../../migration/evidence/CP-3K/reproduction-oracle.json): qualificação oficial no Oracle 19c.
- [Fechamento CP-3K](../../migration/evidence/CP-3K/closure.properties): contratos, WAR, auditoria e resultado final.

**Notas do apresentador**

_A redigir na tarefa 2.3._

## Slide 8 — Incompatibilidades: não foi apenas trocar versões

**Mensagem central**

_A redigir na tarefa 2.3._

**Texto básico**

_A redigir na tarefa 2.3._

**Evidências**

- [Catálogo de incompatibilidades](../../migration/incompatibility-catalog.md): visualização das falhas, causas, correções e provas.
- [Índice estruturado de incompatibilidades](../../migration/incompatibilities.tsv): conjunto completo de ocorrências catalogadas.
- [Conclusão do projeto — lições 6 a 9](../project-conclusion.md): WAR, bibliotecas abandonadas, Jakarta e datasource.

**Notas do apresentador**

_A redigir na tarefa 2.3._

## Slide 9 — Lições que reduzem risco em uma migração real

**Mensagem central**

_A redigir na tarefa 2.4._

**Texto básico**

_A redigir na tarefa 2.4._

**Evidências**

- [Conclusão do projeto — lições aprendidas](../project-conclusion.md): doze conclusões derivadas dos checkpoints.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): contratos preservados, auditoria, fixtures e dupla qualificação.

**Notas do apresentador**

_A redigir na tarefa 2.4._

## Slide 10 — O que o laboratório não prova

**Mensagem central**

_A redigir na tarefa 2.4._

**Texto básico**

_A redigir na tarefa 2.4._

**Evidências**

- [Conclusão do projeto — propósito e limites](../project-conclusion.md): itens explicitamente fora do escopo.
- [Relatório CP-3K — cenários não executados e limitações](../evidence/CP-3K.md): restrições de H2, Oracle, carga, failover e produção.

**Notas do apresentador**

_A redigir na tarefa 2.4._

## Slide 11 — Como aplicar o método em uma aplicação real

**Mensagem central**

_A redigir na tarefa 2.5._

**Texto básico**

_A redigir na tarefa 2.5._

**Evidências**

- [Conclusão do projeto — aplicação em sistema real](../project-conclusion.md): etapas de inventário até implantação.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): papéis, janela, go/no-go e rollback.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): critérios reutilizáveis de gates e evidência.

**Notas do apresentador**

_A redigir na tarefa 2.5._

## Slide 12 — Decisão proposta e próximos passos

**Mensagem central**

_A redigir na tarefa 2.5._

**Texto básico**

_A redigir na tarefa 2.5._

**Evidências**

- [Conclusão do projeto — critérios recomendados para cada gate](../project-conclusion.md): condições mínimas de aprovação e primeira entrega.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): responsabilidades, preparação e decisão de corte.
- [Checkpoints do laboratório](../checkpoints.md): referência para estruturar entregas pequenas e rastreáveis.

**Notas do apresentador**

_A redigir na tarefa 2.5._
