# Documentação do laboratório

Use esta página como índice. Procedimentos operacionais ficam em um único
runbook; documentos de arquitetura, decisões e evidências não repetem esses
passos.

## Comece aqui

1. [Preparação do ambiente](environment-setup.md): componentes, versões,
   downloads, licenças, checksums e configuração do `.env`.
2. [Operação e testes manuais da aplicação legada](legacy-application-runbook.md):
   diagnóstico, build, preparação do banco, start, URLs, casos manuais, stop,
   limpeza e solução de problemas.
3. [Checkpoints](checkpoints.md): entregas incrementais e tags das três fases.
4. [Fluxo GitHub](github-workflow.md): branches, pull requests, checks e squash.
5. [Reprodução do baseline legado](legacy-baseline-reproduction.md): checkout
   limpo, validações H2/Oracle, limpeza e rollback da fase 1.
6. [CP-2A — Java 8 no WildFly 9](cp-2a-java8-wildfly9.md): download fixado,
   tentativa antes da correção, build, contratos e rollback.
7. [CP-2B — WildFly 26 no Java 8](cp-2b-wildfly26.md): runtime fixado,
   tentativa do WAR anterior sem correção e evolução da configuração.
8. [CP-2C — EE 8, Maven e datasource](cp-2c-ee8-maven-datasource.md):
   alinhamento das APIs, ferramenta de build e qualificação da persistência.
9. [Evidência CP-2C](evidence/CP-2C.md): resultados H2/Oracle, conclusões
   comprovadas, limites e rollback do checkpoint.
10. [Evidência CP-2D](evidence/CP-2D.md): comparação integral dos contratos,
    estado Oracle oficial e limites da qualificação portátil da fase 2.

## Aplicação e arquitetura

- [Estrutura do repositório](repository-layout.md);
- [modelo mínimo do domínio](legacy-domain-model.md);
- [dependências do WAR legado](legacy-dependencies.md);
- [persistência MyBatis](mybatis-persistence.md).
- [upload legado e metadados comparáveis](legacy-upload.md).
- [importação XML legada](legacy-xml-import.md).
- [descoberta Reflections e logging Log4j 1](legacy-validation-logging.md).

## Runtime e banco

- [Runtime legado externo](../runtime/legacy/README.md);
- [Runtime Java 8/WildFly 9 do CP-2A](../runtime/phase2/java8-wildfly9/README.md);
- [Runtime Java 8/WildFly 26 do CP-2B](../runtime/phase2/java8-wildfly26/README.md);
- [seleção Java 7/H2 do CP-1D](cp-1d-runtime-selection.md);
- [diferenças H2/Oracle](h2-oracle-differences.md);
- [aprovação do schema Oracle](oracle-lab-schema.md).

## Histórico e evidências

Os arquivos em [`docs/evidence/`](evidence/) registram o que foi executado em
cada checkpoint. Eles não são runbooks ativos e não devem ser usados
isoladamente para iniciar o ambiente.

O [Codex handoff](codex-handoff.md) preserva o estado da sessão de trabalho,
as decisões já consolidadas e as próximas ações sem reproduzir segredos locais.

As falhas de migração e suas correções ficam em
[`migration/steps/`](../migration/steps/), com índice estruturado em
[`migration/incompatibilities.tsv`](../migration/incompatibilities.tsv). Os
valores congelados da fase 1 ficam em
[`migration/baselines/01-legacy/`](../migration/baselines/01-legacy/). O
planejamento executável e os critérios normativos permanecem em
[`openspec/changes/create-java-web-migration-lab/`](../openspec/changes/create-java-web-migration-lab/).
