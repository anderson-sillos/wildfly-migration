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
11. [Roteiro da fase 2 para uma aplicação real](phase2-real-application-migration-runbook.md):
    janela de transição, implantação blue/green, go/no-go e rollback.
12. [Reprodução da fase 2](phase2-reproduction.md): checkout limpo,
    configuração externa segura e qualificação H2/Oracle.
13. [Evidência CP-3A](evidence/CP-3A.md): tentativa do WAR imutável da fase 2
    no Java 17/WildFly 26 antes de qualquer correção.
14. [Evolução WildFly × Java SE](wildfly-java-compatibility.md): matriz
    histórica revisada, distinção entre runtime e certificação Jakarta EE e
    relação com os gates do laboratório.
15. [Matriz de dependências do CP-3A](cp-3a-dependency-matrix.md): candidatos
    para Java 17/EE 8, transitivas, impacto, decisão e sequência de aplicação.
16. [Runtime Java 17/WildFly 26 do CP-3A](cp-3a-java17-runtime.md): versões
    fixas, H2 2.4.240, preparação, validação e rollback.
17. [Dependências centrais do CP-3B](cp-3b-core-dependencies.md): atualizações
    isoladas, qualificação H2/Oracle e rollback do gate Java 17.
18. [Ponte de logging do CP-3B](cp-3b-logging-bridge.md): retirada do Log4j 1,
    integração transitória com SLF4J/JBoss LogManager e validação do MDC.
19. [FileUpload 1.x no CP-3B](cp-3b-fileupload.md): atualização compatível
    com `javax`, limites, temporários e validação H2/Oracle.
20. [Reflections 0.10.2 no CP-3B](cp-3b-reflections-bridge.md): annotation,
    scanners, TCCL, conjunto e ordem de validadores no WildFly 26.
21. [Evidência CP-3B](evidence/CP-3B.md): resultados parciais das atualizações
    centrais e conclusão consolidada no fechamento do checkpoint.
22. [XMLBeans 5.3.0 do CP-3C](cp-3c-xmlbeans.md): geração dos tipos a partir
    do XSD, validação de namespace/serialização e auditoria do WAR.
23. [dom4j 2.2.0 do CP-3C](cp-3c-dom4j.md): coordenada moderna, reader seguro
   e rejeição de XXE/expansão de entidades.
24. [APIs XML do Java 17 no CP-3C](cp-3c-java-xml-apis.md): remoção de
    xml-apis/Geronimo StAX e comprovação do módulo java.xml.
25. [Oracle JDBC do CP-3C](cp-3c-ojdbc17.md): troca do driver externo,
    fornecimento externo, perfis H2/Oracle e qualificação de persistência.
26. [Evidência CP-3C](evidence/CP-3C.md): auditoria consolidada de XML,
    dependências, H2, Oracle e rollback do checkpoint.

## Aplicação e arquitetura

- [Estrutura do repositório](repository-layout.md);
- [modelo mínimo do domínio](legacy-domain-model.md);
- [dependências do WAR legado](legacy-dependencies.md);
- [matriz de modernização das dependências no CP-3A](cp-3a-dependency-matrix.md);
- [dependências centrais do CP-3B](cp-3b-core-dependencies.md);
- [ponte temporária de logging do CP-3B](cp-3b-logging-bridge.md);
- [Commons FileUpload 1.x transitório no CP-3B](cp-3b-fileupload.md);
- [Reflections 0.10.2 transitório no CP-3B](cp-3b-reflections-bridge.md);
- [XMLBeans 5.3.0 e tipos gerados do CP-3C](cp-3c-xmlbeans.md);
- [dom4j 2.2.0 e parsing seguro do CP-3C](cp-3c-dom4j.md);
- [APIs XML do Java 17 no CP-3C](cp-3c-java-xml-apis.md);
- [Oracle JDBC 17 do CP-3C](cp-3c-ojdbc17.md);
- [persistência MyBatis](mybatis-persistence.md);
- [upload legado e metadados comparáveis](legacy-upload.md);
- [importação XML legada](legacy-xml-import.md);
- [descoberta Reflections e evolução do logging](legacy-validation-logging.md).

## Runtime e banco

- [Runtime legado externo](../runtime/legacy/README.md);
- [Runtime Java 8/WildFly 9 do CP-2A](../runtime/phase2/java8-wildfly9/README.md);
- [Runtime Java 8/WildFly 26 do CP-2B](../runtime/phase2/java8-wildfly26/README.md);
- [Runtime Java 17/WildFly 26 do CP-3A](../runtime/phase3/java17-wildfly26/README.md);
- [evolução da compatibilidade WildFly × Java SE](wildfly-java-compatibility.md);
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
