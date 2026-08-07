# Relatório consolidado — CP-3K e laboratório de migração

## Objetivo e estado do relatório

Este relatório consolida a evolução da mesma aplicação nas três fases públicas
do laboratório, os gates intermediários, as versões fixadas, as evidências e os
limites conhecidos. Ele foi iniciado na atividade 3.52 e concluído no
fechamento 3.55.

O destino final está aprovado pelas trilhas `portable-ci` e
`oracle-qualified`, pela reprodução a partir de checkout limpo e pela auditoria
final. A PR #30 é integrada pelo assunto obrigatório
`checkpoint(CP-3K): complete final destination`, e o mesmo commit recebe a tag
`migration/03-final`. H2 e Oracle permanecem apresentados em estados
separados; H2 nunca substitui a qualificação Oracle.

## Três fases públicas

| Fase | Entrada e objetivo | Runtime e banco de referência | Saída aprovada |
| --- | --- | --- | --- |
| 1 — Baseline legado | Preservar o comportamento Java EE 7 antes da modernização | Oracle JDK 7u80, Maven 3.8.9, WildFly 9.0.2.Final, H2 1.4.200 para `portable-ci`, Oracle 19c/`ojdbc7` para `oracle-qualified` | `CP-1G`, tag `migration/01-legacy-baseline`, 14/14 contratos |
| 2 — Java 8 e WildFly compatível | Modernizar o runtime com o menor impacto no código `javax` | Temurin 8u492, Maven 3.9.16, WildFly 26.1.3.Final, H2 1.4.200, Oracle 19c/`ojdbc7` | `CP-2D`, tag `migration/02-java8-wildfly26`, 14/14 contratos |
| 3 — Destino Jakarta/OpenJDK | Atualizar dependências, namespace e servidor mantendo gates reproduzíveis | Temurin OpenJDK 25.0.4+7, WildFly Community 41.0.0.Final, Jakarta EE 11, H2 2.4.240, Oracle 19c/`ojdbc17` 23.26.2.0.0 | `CP-3K`, tag `migration/03-final`, 15/15 contratos em Java 21 e 25 |

As origens, licenças e SHA-256 dos arquivos estão nos manifestos de runtime:
[`legacy`](../../runtime/legacy/runtime-manifest.tsv),
[`Java 8/WildFly 26`](../../runtime/phase2/java8-wildfly26/runtime-manifest.tsv),
[`Java 17/WildFly 26`](../../runtime/phase3/java17-wildfly26/runtime-manifest.tsv),
[`Java 21/WildFly 41`](../../runtime/phase3/java21-wildfly41/runtime-manifest.tsv) e
[`Java 25/WildFly 41`](../../runtime/phase3/java25-wildfly41/runtime-manifest.tsv).

## Checkpoints e gates

| Checkpoint | Papel no roteiro | Estado `portable-ci` | Estado `oracle-qualified` | Evidência principal |
| --- | --- | --- | --- | --- |
| CP-1A a CP-1C | Repositório, runtime legado, WAR e dependências | aprovado | aprovado quando aplicável | [`CP-1C`](CP-1C.md) |
| CP-1D a CP-1F | H2, datasource, fluxo web, XML e contratos | aprovado | aprovado | [`CP-1F`](CP-1F.md) |
| CP-1G | Baseline congelado | 14/14 | 14/14 | [`CP-1G`](CP-1G.md) |
| CP-2A a CP-2C | Java 8, WildFly 26, Maven e EE 8 | aprovado, 14/14 | aprovado, 14/14 | [`CP-2C`](CP-2C.md) |
| CP-2D | Fechamento da fase 2 | aprovado, 14/14 | aprovado, 14/14 | [`CP-2D`](CP-2D.md) |
| CP-3A a CP-3C | Java 17, dependências, XML e JDBC | aprovado, 14/14 | aprovado, 14/14 | [`CP-3C`](CP-3C.md) |
| CP-3D | Gate Java 17/WildFly 26 | aprovado, 14/14 | aprovado, 14/14 | [`CP-3D`](CP-3D.md) |
| CP-3E a CP-3G | WildFly 41, Jakarta EE, web, SCI e logging | aprovado, 15/15 | aprovado, 15/15 quando qualificado | [`CP-3G`](CP-3G.md) |
| CP-3H | XML seguro, datasource e auditoria do WAR | aprovado, 15/15 | aprovado, 15/15 | [`CP-3H`](CP-3H.md) |
| CP-3I | Gate Java 21 e semântica de persistência | aprovado, 15/15 | aprovado, 15/15 | [`CP-3I`](CP-3I.md) |
| CP-3J | OpenJDK 25 no WildFly 41 | 15/15 em Java 21 e 25 | 15/15 em Java 21 e 25 | [`CP-3J`](CP-3J.md) |
| CP-3K | Consolidação, reprodução, auditoria e tag final | aprovado, 15/15 | aprovado, 15/15 | este relatório e evidências 3.53–3.55 |

O cenário `protectedFragments` foi acrescentado ao conjunto de 14 cenários do
baseline a partir dos gates Jakarta; por isso os gates CP-3F em diante registram
15/15. A diferença é documentada em [`CP-3I`](CP-3I.md), sem alterar os 14
cenários originais.

## Exceções e incompatibilidades resolvidas

O índice completo está em [`migration/incompatibilities.tsv`](../../migration/incompatibilities.tsv)
e seus registros detalhados em [`migration/steps/`](../../migration/steps/).
As principais transições comprovadas foram:

- Java 7 → 8 → 17 → 21 → 25 com a política de compilação final
  `maven.compiler.release=21`;
- WildFly 9 → 26.1.3 → 41, incluindo a migração `javax.*` para `jakarta.*`;
- Log4j 1 e ponte concorrente removidos, com logging SLF4J/JBoss LogManager;
- MyBatis 3.4.5 → 3.5.19 com `logImpl=SLF4J`;
- Commons FileUpload substituído por multipart nativo do Servlet/Jakarta;
- Reflections substituído por `ServletContainerInitializer` com
  `@HandlesTypes`;
- Tiles 2.1.4 substituído por tag file/includes JSP protegidos;
- XMLBeans, dom4j, APIs XML duplicadas e parsing XXE atualizados ou removidos;
- `ojdbc7` substituído por `ojdbc17` externo ao WAR e fornecido por módulo do
  WildFly 41.

As falhas naturais e as duas fixtures que precisam de opt-in explícito são
descritas no [catálogo de incompatibilidades](../../migration/incompatibility-catalog.md).
Fixtures não são executadas no fluxo funcional padrão.

## Ambientes e classificação dos resultados

`portable-ci` é a trilha executada no CI hospedado: runtime open source,
WildFly em loopback, H2 em memória, contratos HTTP, auditoria de dependências,
empacotamento, segredos e portas. Seu resultado comprova a parte portátil do
laboratório.

`oracle-qualified` é a mesma validação executada com Oracle Database 19c RU
19.3, schema descartável autorizado, driver externo correspondente ao gate e
credenciais mantidas fora do Git. Ela comprova somente os comportamentos
observados nessa instância; não autoriza copiar credenciais ou drivers para o
WAR.

Os dois estados estão vinculados ao commit-fonte, checksum do WAR, manifesto de
runtime e relatório sanitizado de cada checkpoint. Os agregadores CP-3H, CP-3I
e CP-3J estão em [`migration/evidence/`](../../migration/evidence/).

## Cenários não executados e limitações

- O CI hospedado não acessa a rede interna do Oracle; qualquer execução Oracle
  ausente em uma reprodução deve ser marcada como `não validada`, nunca como
  aprovada.
- H2 em modo Oracle não cobre completamente tipos, locks, planos, permissões,
  sequência e comportamento do driver Oracle; a qualificação final exige a
  segunda trilha.
- As fixtures `FIX-001` e `FIX-002` são opt-in porque seus dados não são uma
  falha natural determinística ou envolvem uma tentativa de entidade externa;
  não são parte do smoke padrão.
- Não há teste de carga, failover, disponibilidade de produção ou certificação
  de um banco diferente do Oracle 19c documentado.
- A qualificação Oracle representa a instância 19c RU 19.3 observada; o
  inventário de patches `one-off` do Oracle Home não foi fornecido.

As reproduções da atividade 3.53 estão registradas em
[`reproduction-ci-h2.json`](../../migration/evidence/CP-3K/reproduction-ci-h2.json)
(`portable-ci`) e
[`reproduction-oracle.json`](../../migration/evidence/CP-3K/reproduction-oracle.json)
(`oracle-qualified`). Os dois relatórios usam o mesmo WAR Java 25, com SHA-256
`80876fc3ee480cbdda32e948aaf3a8d5151dacf883717254fda943cb5af33270`.

## Auditoria 3.54

O script `scripts/audit-cp-3k.sh` verificou os 12 commits de fechamento
anteriores, as duas tags públicas, a rastreabilidade das PRs #18, #20, #21,
#23, #24, #25, #28, #29 e #30, a ausência antecipada da tag final, segredos,
licenças, origens HTTPS, SHA-256, dependências proibidas, WAR e rollback. A
evidência sanitizada está em
[`audit.properties`](../../migration/evidence/CP-3K/audit.properties) e foi
validada por `scripts/validate-cp-3k-audit.sh`.

## Reprodução e rollback

O ponto de entrada operacional é [`environment-setup.md`](../environment-setup.md),
seguido pelo `doctor`, pelos scripts do checkpoint e pelo runbook de cada fase.
A reprodução final foi registrada na atividade 3.53 a partir de checkout limpo,
sem `.env`, credenciais, JDK, WildFly ou driver proprietário versionados.

Cada checkpoint retorna ao último commit verde documentado, sem `DROP USER`,
remoção de schema ou alteração destrutiva no Oracle. As evidências de rollback
estão nos diretórios `migration/evidence/CP-*/` correspondentes. O CP-3K retorna
ao CP-3J pelo runtime e WAR já aprovados, sem mutação de banco.

As lições aprendidas e a aplicação recomendada deste método em um sistema real
estão consolidadas na [conclusão do projeto](../project-conclusion.md).

## Fechamento 3.55

O fechamento aprovou as evidências H2 e Oracle, a reprodução limpa, a auditoria
de histórico/segurança/proveniência, o WAR e o rollback. O resumo verificável
está em
[`closure.properties`](../../migration/evidence/CP-3K/closure.properties) e
[`rollback.properties`](../../migration/evidence/CP-3K/rollback.properties).

## Conclusão desta atividade

As três fases, os gates, as versões e a distinção entre `portable-ci` e
`oracle-qualified` estão consolidados e rastreáveis. O destino final está
aprovado em OpenJDK 25/WildFly 41/Jakarta EE 11 e preservado pela tag
`migration/03-final`.
