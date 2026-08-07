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

`Comprovado no laboratório`: dividir a jornada em três fases públicas permitiu preservar o comportamento, modernizar primeiro com baixo impacto e tratar depois as rupturas arquiteturais do destino final.

**Texto básico**

- **Fase 1 — Baseline legado:** tornar Java 7/WildFly 9 observável, reproduzível e testável.
- **Fase 2 — Baixo impacto:** avançar para Java 8/WildFly 26 preservando o modelo `javax` e os contratos.
- **Fase 3 — Destino final:** atualizar dependências, migrar para Jakarta e qualificar OpenJDK 25/WildFly 41.
- Java 17 e Java 21 funcionaram como gates técnicos para separar dependências, Jakarta e JVM final.
- A evolução ocorreu sobre uma única aplicação; tags preservaram os três estados públicos.

**Evidências**

- [Conclusão do projeto — planejamento executado](../project-conclusion.md): objetivos e plataformas aprovadas nas três fases.
- [Relatório CP-3K — três fases públicas](../evidence/CP-3K.md): entradas, runtimes e saídas aprovadas.
- [Checkpoints do laboratório](../checkpoints.md): decomposição das fases em entregas incrementais.

**Notas do apresentador**

Explicar que os gates são pontos de verificação de engenharia, não necessariamente ambientes que devem entrar em produção. A fase 2 oferece uma ponte de menor ruptura para organizações que precisam reduzir risco antes do salto Jakarta. Em uma aplicação real, versões e quantidade de gates podem mudar depois do inventário; a função de cada fase deve permanecer clara.

## Slide 5 — Como reduzimos o risco: checkpoints, evidência e rollback

**Mensagem central**

`Comprovado no laboratório`: checkpoints pequenos converteram uma migração longa em decisões verificáveis, cada uma com causa diagnosticável, evidência de aprovação e retorno ao último estado verde.

**Texto básico**

- Executar o último artefato aprovado no próximo runtime antes de corrigi-lo.
- Alterar um grupo coerente de riscos e repetir os mesmos contratos.
- Integrar por commit e PR com critérios objetivos de aprovação.
- Vincular evidência ao artefato, runtime, banco e resultado realmente testados.
- Manter o runtime anterior e um procedimento de rollback para cada fechamento.

**Evidências**

- [Checkpoints do laboratório](../checkpoints.md): conteúdo mínimo de cada entrega e registros de rollback.
- [Fluxo GitHub](../github-workflow.md): branches, pull requests e gates de integração.
- [Conclusão do projeto — lições 3, 10 e 12](../project-conclusion.md): falha antes da correção, evidência durável e checkpoints pequenos.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): requisitos normativos de evidência, fechamento e retorno ao estado verde.

**Notas do apresentador**

Destacar que a primeira falha é uma evidência útil: ela identifica a incompatibilidade antes que várias correções escondam sua origem. “Rollback” não significa restaurar banco automaticamente; significa ter artefato, runtime e configuração anteriores disponíveis, além de um procedimento aprovado para proteger e reconciliar dados. Checkpoints menores também reduzem o escopo de revisão e de decisão gerencial.

## Slide 6 — A evolução alcançada

**Mensagem central**

`Comprovado no laboratório`: o destino não foi apenas uma JVM mais nova; runtime, APIs, bibliotecas, empacotamento, logging, upload, XML e acesso ao banco foram modernizados de forma coordenada.

**Texto básico**

- **Origem:** Java 7u80, WildFly 9.0.2 e APIs Java EE da geração `javax`.
- **Destino:** OpenJDK 25, WildFly 41 e Jakarta EE 11, usando somente distribuições open source no runtime final.
- Bibliotecas abandonadas foram substituídas por padrões do Servlet/Jakarta ou mecanismos encapsulados pela aplicação.
- MyBatis, XML e JDBC foram atualizados preservando a fronteira de datasource JNDI.
- APIs do servidor e driver Oracle ficaram fora do WAR, reduzindo conflitos de classloader e empacotamento.

**Evidências**

- [Relatório CP-3K — três fases públicas](../evidence/CP-3K.md): versões e contratos aprovados em cada destino.
- [Conclusão do projeto — resultado técnico](../project-conclusion.md): stack final e bibliotecas substituídas.
- [Spec da aplicação Jakarta moderna](../../openspec/specs/modern-jakarta-webapp/spec.md): requisitos do runtime final e da equivalência funcional.

**Notas do apresentador**

Evitar transformar este slide em inventário de bibliotecas. O ponto gerencial é que modernizar a plataforma exigiu tratar também componentes invisíveis ao usuário: descritores, módulos do servidor, pool de conexão, logging e conteúdo do WAR. O runtime final usa OpenJDK e WildFly Community; o Oracle continua sendo o banco oficial e seu driver é provisionado externamente.

## Slide 7 — O que foi efetivamente comprovado

**Mensagem central**

`Comprovado no laboratório`: o mesmo comportamento essencial foi preservado até o destino final e validado tanto no ambiente portátil quanto no Oracle oficial do laboratório.

**Texto básico**

- Os 14 contratos funcionais do baseline permaneceram válidos durante a evolução.
- O destino Jakarta acrescentou segurança de fragmentos web e encerrou com 15/15 cenários aprovados.
- O mesmo WAR final foi executado em OpenJDK 21 e 25, com H2 e Oracle 19c RU 19.3.
- A reprodução partiu de checkout limpo, sem credenciais ou binários restritos versionados.
- Auditorias verificaram dependências, conteúdo do WAR, versões, origens, checksums e rollback.

**Evidências**

- [Relatório CP-3K — checkpoints e ambientes](../evidence/CP-3K.md): resultados `portable-ci` e `oracle-qualified`.
- [Reprodução final em H2](../../migration/evidence/CP-3K/reproduction-ci-h2.json): execução portátil a partir de checkout limpo.
- [Reprodução final em Oracle](../../migration/evidence/CP-3K/reproduction-oracle.json): qualificação oficial no Oracle 19c.
- [Fechamento CP-3K](../../migration/evidence/CP-3K/closure.properties): contratos, WAR, auditoria e resultado final.

**Notas do apresentador**

Explicar que H2 e Oracle têm papéis diferentes: H2 oferece feedback remoto rápido; Oracle qualifica o comportamento oficial de persistência. “15/15” não significa cobertura total da aplicação, e sim aprovação de todos os cenários definidos para o laboratório. O resultado comprova o escopo modelado — fluxo web, sessão, upload, XML, persistência e aspectos de segurança — e não requisitos externos que não foram representados.

## Slide 8 — Incompatibilidades: não foi apenas trocar versões

**Mensagem central**

`Comprovado no laboratório`: 27 incompatibilidades foram catalogadas; as causas alcançaram código, build, servidor, empacotamento, configuração e banco, confirmando que uma atualização direta ocultaria riscos diferentes sob uma única falha.

**Texto básico**

- JVM e build: versões de bytecode, plugins e opções removidas precisaram ser alinhados.
- Java EE → Jakarta: imports, descritores, JSP/JSTL, TLD e bibliotecas web atravessaram a fronteira de namespace.
- Bibliotecas abandonadas: Tiles, Commons FileUpload, Reflections e Log4j 1 foram substituídos pelo contrato que cumpriam.
- Runtime: datasource, driver, logging e APIs fornecidas pelo servidor exigiram configuração e auditoria do WAR.
- Banco e XML: compatibilidade portátil não substituiu qualificação Oracle nem testes de parsing seguro.

**Evidências**

- [Catálogo de incompatibilidades](../../migration/incompatibility-catalog.md): visualização das falhas, causas, correções e provas.
- [Índice estruturado de incompatibilidades](../../migration/incompatibilities.tsv): conjunto completo de ocorrências catalogadas.
- [Conclusão do projeto — lições 6 a 9](../project-conclusion.md): WAR, bibliotecas abandonadas, Jakarta e datasource.

**Notas do apresentador**

Usar poucos exemplos para mostrar amplitude, não para explicar implementação. A troca do Reflections por um mecanismo padrão do Servlet preservou a descoberta automática; o upload passou a usar a API nativa; Tiles foi substituído por recursos JSP protegidos. Cada correção foi associada à falha anterior e a uma prova posterior, formando um catálogo reutilizável na investigação de uma aplicação real.

## Slide 9 — Lições que reduzem risco em uma migração real

**Mensagem central**

`Recomendação para aplicação real`: o ativo mais reutilizável do laboratório é a disciplina de produzir estados conhecidos e aprovados; versões específicas podem mudar, mas os controles de evidência e decisão devem permanecer.

**Texto básico**

- Tratar o baseline como a primeira entrega, não como preparação informal.
- Mudar poucas dimensões por gate para preservar a capacidade de diagnóstico.
- Validar contratos externos e o WAR efetivo, não apenas compilação e `pom.xml`.
- Usar CI portátil para velocidade e o banco oficial para qualificação.
- Vincular cada aprovação a artefato, runtime, evidência, limitações e rollback.

**Evidências**

- [Conclusão do projeto — lições aprendidas](../project-conclusion.md): doze conclusões derivadas dos checkpoints.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): contratos preservados, auditoria, fixtures e dupla qualificação.

**Notas do apresentador**

Reforçar que a organização não precisa copiar exatamente Java 8, 17 ou 21 como gates. Ela precisa escolher pontos que isolem riscos relevantes da sua aplicação. O baseline reduz discussão subjetiva sobre regressões; a inspeção do artefato encontra dependências que a compilação não revela; e a evidência durável permite auditoria mesmo depois de squash, limpeza de branches ou mudança de ambiente.

## Slide 10 — O que o laboratório não prova

**Mensagem central**

`Limitação`: o laboratório comprova o método e o escopo representado, mas não certifica automaticamente uma aplicação real nem fornece estimativa de prazo, custo ou risco residual sem inventário e testes próprios.

**Texto básico**

- Não foram exercitados carga, cluster, failover, alta disponibilidade ou disaster recovery.
- Integrações, segurança, jobs, filas, EAR/EJB e regras de domínio não representadas exigem gates próprios.
- H2 não cobre integralmente SQL, locks, planos, tipos, permissões ou comportamento do driver Oracle.
- A qualificação oficial observou Oracle 19c RU 19.3; patches adicionais do ambiente não foram inventariados.
- Prazo, orçamento, equipe e janela de implantação dependem do diagnóstico da aplicação selecionada.

**Evidências**

- [Conclusão do projeto — propósito e limites](../project-conclusion.md): itens explicitamente fora do escopo.
- [Relatório CP-3K — cenários não executados e limitações](../evidence/CP-3K.md): restrições de H2, Oracle, carga, failover e produção.

**Notas do apresentador**

Apresentar limites como controle de decisão, não como enfraquecimento do resultado. O laboratório evita prometer compatibilidade universal: ele oferece um método para descobrir o que é específico de cada sistema antes da produção. Uma aplicação com EAR, EJB, JMS, integrações externas, SQL proprietário ou requisitos intensivos de disponibilidade terá atividades adicionais e possivelmente mais gates.

## Slide 11 — Como aplicar o método em uma aplicação real

**Mensagem central**

`Recomendação para aplicação real`: iniciar por uma aplicação piloto e financiar primeiro conhecimento verificável — inventário e baseline — antes de assumir destino, cronograma ou janela de produção.

**Texto básico**

- Selecionar o piloto e formar responsáveis de negócio, aplicação, plataforma, DBA e segurança.
- Inventariar artefato, runtime, dependências, configurações, dados e integrações reais.
- Reconstruir o legado e congelar contratos dos fluxos críticos no banco oficial.
- Planejar gates para JVM, servidor, dependências e Jakarta conforme os riscos encontrados.
- Ensaiar implantação paralela, critérios de go/no-go, observabilidade e rollback antes do corte.

**Evidências**

- [Conclusão do projeto — aplicação em sistema real](../project-conclusion.md): etapas de inventário até implantação.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): papéis, janela, go/no-go e rollback.
- [Spec do laboratório de compatibilidade](../../openspec/specs/migration-compatibility-lab/spec.md): critérios reutilizáveis de gates e evidência.

**Notas do apresentador**

O primeiro compromisso não é migrar tudo: é produzir um diagnóstico confiável. O baseline deve associar fonte, artefato, checksum, configuração e comportamentos críticos. Só então a equipe consegue propor versões, quantidade de gates, esforço e riscos residuais. A implantação recomendada mantém ambiente anterior e novo em paralelo, com corte controlado e proteção explícita dos dados.

## Slide 12 — Decisão proposta e próximos passos

**Mensagem central**

`Recomendação para aplicação real`: autorizar uma etapa limitada de enquadramento e baseline para converter incerteza em evidência antes de decidir pela execução completa da migração.

**Texto básico**

- Selecionar uma aplicação piloto com relevância e escopo administrável.
- Nomear patrocinador e responsáveis multidisciplinares pela decisão técnica e de negócio.
- Autorizar inventário, ambiente isolado, acesso controlado ao banco e construção do baseline.
- Definir critérios de sucesso, riscos que exigem escalonamento e formato das evidências.
- Retornar à liderança com diagnóstico, alternativas, roadmap, estimativa e recomendação de continuidade.

**Evidências**

- [Conclusão do projeto — critérios recomendados para cada gate](../project-conclusion.md): condições mínimas de aprovação e primeira entrega.
- [Roteiro de migração para aplicação real](../phase2-real-application-migration-runbook.md): responsabilidades, preparação e decisão de corte.
- [Checkpoints do laboratório](../checkpoints.md): referência para estruturar entregas pequenas e rastreáveis.

**Notas do apresentador**

Fechar com uma decisão objetiva: aprovar a descoberta e o baseline do piloto, não uma migração cega nem um corte em produção. A primeira entrega deve permitir responder o que existe, o que precisa ser preservado, quais bloqueios são reais e quais caminhos são viáveis. Prazo, custo e plano final serão apresentados depois dessa evidência, com opções e critérios de go/no-go para a liderança.
