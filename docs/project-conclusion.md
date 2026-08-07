# Conclusão do projeto — laboratório de migração Java e WildFly

## Propósito

Este projeto foi criado para demonstrar uma migração incremental de uma
aplicação web Java antiga sem transformar o trabalho em uma reescrita. A mesma
árvore `app/` começou com Java 7u80, WildFly 9.0.2, APIs `javax.*`, JSP, Tiles,
Commons FileUpload, Reflections, Log4j 1, MyBatis, XMLBeans, dom4j e Oracle 19c
e evoluiu até OpenJDK 25, WildFly Community 41 e Jakarta EE 11.

O objetivo principal não foi apenas produzir um WAR moderno. O laboratório
procurou construir um método aplicável a uma aplicação real:

- preservar primeiro um baseline funcional e reconstruível;
- mudar poucas dimensões da plataforma por vez;
- capturar a incompatibilidade antes de aplicar a correção;
- manter contratos externos iguais durante a evolução;
- separar feedback portátil de qualificação no banco oficial;
- registrar versões, origens, licenças, checksums e conteúdo do WAR;
- entregar checkpoints pequenos, rastreáveis e reversíveis.

O projeto não substitui uma avaliação da aplicação real. Ele não cobre todo o
domínio, carga, cluster, alta disponibilidade, disaster recovery, integrações
externas não representadas, procedures ou tipos Oracle proprietários.

## Planejamento executado

A migração foi organizada em três fases públicas sobre uma única linha de
código. Java 17 e Java 21 foram usados como gates técnicos da fase final, não
como fases adicionais.

| Fase | Objetivo | Plataforma aprovada | Resultado principal |
| --- | --- | --- | --- |
| 1 — Baseline legado | Tornar o comportamento antigo observável e reproduzível antes de modernizar | Java 7u80, Maven 3.8.9 e WildFly 9.0.2 | contratos, persistência, WAR e inventário congelados em `migration/01-legacy-baseline` |
| 2 — Modernização de baixo impacto | Modernizar JVM e servidor sem iniciar a ruptura `javax` → `jakarta` | Java 8, Maven 3.9.16, WildFly 26.1.3 e EE 8/`javax` | ponte operacional validada em `migration/02-java8-wildfly26` |
| 3 — Destino final | Modernizar dependências, migrar Jakarta, substituir bibliotecas abandonadas e qualificar a JVM final | OpenJDK 25.0.4+7, WildFly 41.0.0.Final e Jakarta EE 11 | destino aprovado e preservado em `migration/03-final` |

O gate Java 17/WildFly 26 isolou atualização de dependências ainda compatíveis
com EE 8. O gate Java 21/WildFly 41 isolou servidor, namespace Jakarta e
substituições arquiteturais. Só depois disso o WildFly 41 foi executado com
OpenJDK 25. O build final usa o JDK 25 e `--release 21`, mantendo o bytecode e
as APIs-alvo em Java 21; o runtime final é qualificado em Java 25 e há uma
execução adicional em Java 21.

Cada checkpoint parcial teve branch, PR, validação, evidência e rollback. As
tags foram reservadas aos três estados públicos para não confundir entregas de
engenharia com destinos de migração.

## Resultado técnico alcançado

O destino demonstrado pelo laboratório possui:

- runtime Eclipse Temurin OpenJDK 25.0.4+7 e WildFly Community 41.0.0.Final;
- Maven 3.9.16 e Jakarta EE Web Profile 11 em escopo `provided`;
- MyBatis 3.5.19 com `logImpl=SLF4J` e logging administrado pelo WildFly;
- XMLBeans 5.3.0, tipos gerados a partir do XSD e dom4j 2.2.0 com parsing
  seguro;
- `ojdbc17` 23.26.2.0.0 provisionado no WildFly, fora do WAR;
- upload por `@MultipartConfig` e `jakarta.servlet.http.Part`;
- layout JSP por tag files/includes protegidos sob `WEB-INF`;
- descoberta de validadores por `ServletContainerInitializer` e
  `@HandlesTypes`, encapsulada por fachada própria;
- remoção de Log4j 1, Tiles, Commons FileUpload, Reflections, `xml-apis`,
  Geronimo StAX e `ojdbc7` do destino final;
- H2 2.4.240 em memória somente para a trilha portátil;
- Oracle Database 19c RU 19.3 como banco de qualificação oficial.

Os 14 contratos originais do baseline permaneceram válidos. A fase Jakarta
acrescentou a verificação de fragmentos protegidos, chegando a 15 cenários. O
destino final foi executado em H2 e Oracle com OpenJDK 21 e 25, e o mesmo WAR
Java 25 foi reproduzido a partir de checkout limpo. Os detalhes verificáveis
estão no [relatório consolidado CP-3K](evidence/CP-3K.md) e no
[catálogo de incompatibilidades](../migration/incompatibility-catalog.md).

## Lições aprendidas

### 1. O baseline é o primeiro produto da migração

Antes de atualizar uma dependência, foi necessário saber qual WAR estava em
produção, como reconstruí-lo, quais fluxos eram observáveis e qual estado era
persistido. Sem isso, uma compilação bem-sucedida poderia esconder uma mudança
funcional.

Em uma aplicação real, a primeira entrega deve ser uma revisão imutável com
artefato, checksum, configuração inventariada, contratos externos e
qualificação no banco oficial. Se o sistema antigo não puder ser reconstruído,
essa limitação precisa ser tratada como risco de migração, não como detalhe do
pipeline.

### 2. Trocar uma dimensão por vez torna a causa diagnosticável

A sequência Java 7/WildFly 9 → Java 8/WildFly 9 → Java 8/WildFly 26 separou
problemas da JVM de problemas do servidor. Na fase final, Java 17 separou as
dependências do salto Jakarta, e Java 21 separou Jakarta/WildFly 41 da troca
para Java 25.

Uma migração direta pode chegar ao mesmo destino, mas mistura erros de
bytecode, plugins Maven, namespaces, descritores, classloader, datasource e
bibliotecas abandonadas. O tempo economizado ao pular gates costuma reaparecer
como investigação menos precisa e rollback mais arriscado.

### 3. A primeira tentativa deve usar o último estado verde sem correção

Executar o WAR anterior no runtime seguinte revelou falhas reais de
toolchain, opções removidas da JVM, configuração do WildFly, namespace,
classloader e APIs incompatíveis. Isso produziu uma assinatura útil antes que
várias alterações apagassem a causa original.

Fixtures artificiais continuam importantes, mas devem complementar a tentativa
natural. Neste laboratório elas foram opt-in quando a falha não era segura ou
determinística, como validação de domínio e rejeição de entidade XML externa.

### 4. H2 acelera o feedback, mas não qualifica Oracle

O H2 permitiu CI remoto sem expor a rede interna nem credenciais. Ele comprovou
deployment, JNDI, MyBatis, contratos HTTP e a semântica SQL portátil escolhida.
Ao mesmo tempo, surgiram diferenças próprias de constraint e conexão que não
deveriam alterar o DDL Oracle canônico.

Oracle permaneceu obrigatório para driver, sequence, paginação, transações,
timestamps/timezone, CLOB e BLOB. Em uma aplicação real, o resultado portátil
deve ser tratado como feedback rápido; a promoção precisa de uma trilha no
banco e na rede equivalentes ao destino.

### 5. Configuração e runtime também são código da entrega

Parte relevante das incompatibilidades não estava nas classes Java: opções de
JVM, módulos do WildFly, pool de conexão, nome JNDI, logging, keystore, portas
e classloader. Apenas compilar o WAR não provaria que a aplicação poderia ser
operada.

Por isso, versões, downloads, licenças, checksums, módulos e comandos de
provisionamento foram versionados ou manifestados. Segredos e binários
restritos permaneceram externos. A mesma disciplina deve ser aplicada a
imagens, charts, automação de configuração e secret stores da organização.

### 6. O conteúdo efetivo do WAR precisa ser auditado

Escopo Maven incorreto ou dependência transitiva pode empacotar APIs Servlet,
drivers, backends de logging ou bibliotecas que deveriam ser fornecidas pelo
servidor. Esses erros frequentemente passam na compilação e só aparecem no
classloader do ambiente.

A auditoria deve usar o WAR produzido, não apenas o `pom.xml`. No destino, ela
deve reprovar APIs do contêiner e componentes removidos, além de verificar
estruturas obrigatórias, como o descritor `META-INF/services` do SCI.

### 7. Bibliotecas abandonadas devem ser substituídas pelo contrato que elas cumprem

A substituição foi mais segura quando o comportamento foi identificado antes
da biblioteca:

| Biblioteca antiga | Contrato preservado | Solução final |
| --- | --- | --- |
| Tiles | composição de cabeçalho, conteúdo e rodapé | JSP tag files/includes |
| Commons FileUpload | multipart, limites e metadados | Servlet `Part` |
| Reflections | descoberta automática e ordenada de validators | SCI + `@HandlesTypes` + fachada |
| Log4j 1 | categorias, correlação e exceção completa | SLF4J integrado ao WildFly |
| `xml-apis`/Geronimo StAX | APIs XML | módulo `java.xml` do JDK |

Essa abordagem reduz o acoplamento da aplicação real a uma escolha específica
do laboratório. Quando não houver substituição direta, crie uma fachada antes
da troca e congele o comportamento por testes.

### 8. `javax` para `jakarta` é uma fronteira arquitetural

Não se trata apenas de substituir imports. A mudança alcança descritores,
JSP/JSTL, TLD, bibliotecas compiladas contra Servlet antigo e o conteúdo
fornecido pelo servidor. Também é incorreto substituir pacotes Java SE como
`javax.sql`, `javax.naming` e `javax.xml`.

Na aplicação real, faça inventário por bytecode, dependências, descritores e
templates. Não limite a busca aos fontes Java e não misture a transformação de
namespace com todas as atualizações de bibliotecas no mesmo commit.

### 9. Compatibilidade de banco deve preservar a fronteira JNDI

Manter `java:/jdbc/MigrationDS` e o pool sob controle do WildFly permitiu trocar
driver e runtime sem introduzir seleção de fornecedor no código de negócio. O
driver Oracle final ficou fora do WAR, evitando duplicidade e mantendo pool,
credenciais e validação de conexão na plataforma.

Na aplicação real, confirme se há conexões abertas diretamente por
`DriverManager`, URLs em código, pools internos ou SQL dependente do fornecedor.
Esses pontos precisam ser encapsulados antes da troca do servidor.

### 10. Evidência precisa sobreviver ao squash e ao ambiente onde é validada

Relatórios ligados somente a commits temporários de uma branch deixaram de ser
resolvíveis em um checkout remoto que continha apenas o histórico integrado.
A proveniência foi normalizada para o commit squash público com a mesma árvore
de aplicação e runtime.

Para uma aplicação real, o identificador durável deve ser o commit integrado,
a versão do artefato ou uma referência imutável no repositório de artefatos.
Caches e branches temporárias ajudam o processo, mas não podem ser a fonte de
verdade da evidência.

### 11. CI local, CI remoto e IDE têm finalidades diferentes

Maven permaneceu como fonte do classpath e do build. O servidor de linguagem
da IDE precisou reconhecer fontes geradas pelo XMLBeans e ignorar saídas
transitórias sem esconder alertas válidos. O CI remoto validou o checkout e o
runtime portável, enquanto testes Oracle continuaram em ambiente autorizado.

O objetivo não deve ser tornar as ferramentas idênticas, mas alinhar seus
contratos: mesma configuração Maven, warnings relevantes visíveis, geração de
fontes reproduzível e comandos documentados para limpeza e reconstrução.

### 12. Checkpoints pequenos melhoram revisão e rollback

Commits de fechamento identificáveis, PRs por checkpoint e critérios objetivos
reduziram o escopo de cada decisão. O custo adicional de documentação e CI foi
compensado por diagnósticos menores e pontos de retorno claros.

Um rollback real, porém, não é apenas selecionar um commit anterior. Ele exige
runtime anterior disponível, configuração reproduzível e compatibilidade dos
dados escritos depois do corte. Restauração de banco não deve ser automática
nem confundida com rollback de tráfego.

## Como aplicar o método em uma aplicação real

### Etapa 0 — enquadramento e inventário

1. Defina responsáveis de aplicação, plataforma, DBA, segurança e negócio.
2. Identifique o artefato realmente implantado e associe-o ao fonte, quando
   possível.
3. Catalogue JVM, Maven/plugins, servidor, módulos, drivers, datasources,
   segurança, certificados, propriedades, jobs, filas, uploads e integrações.
4. Gere a árvore de dependências e inspecione `WEB-INF/lib`; em EARs, inclua
   `EAR/lib` e todos os módulos.
5. Localize usos de APIs proprietárias do WildFly, Oracle, classloader e
   filesystem.
6. Registre restrições de suporte, EOL, licenciamento e distribuição de cada
   componente.

Saída mínima: inventário revisado, riscos classificados, responsáveis e uma
decisão explícita sobre o destino.

### Etapa 1 — construir o baseline real

1. Reconstrua a versão antiga em ambiente isolado.
2. Crie contratos externos para os fluxos críticos e registre respostas e
   efeitos persistidos.
3. Cubra sessão, autenticação, uploads, XML, relatórios, jobs e integrações que
   existirem no sistema real.
4. Execute os contratos no Oracle oficial ou em uma cópia representativa.
5. Preserve commit, WAR, checksum, runtime, configuração sanitizada, schema e
   instrução de rollback.

Não inicie a modernização enquanto o baseline não conseguir distinguir uma
regressão de uma diferença cosmética.

### Etapa 2 — criar uma ponte de baixo impacto

Adapte a fase 2 à plataforma realmente suportada pela organização. O princípio
é preservar `javax`, regras de negócio, schema e bibliotecas enquanto JVM e
servidor são trocados em passos separados.

1. Troque somente a JVM no servidor atual e corrija o mínimo necessário.
2. Recompile e execute todos os contratos.
3. Instale o servidor intermediário em paralelo; não atualize o servidor antigo
   in-place.
4. Recrie módulos e configurações declarativamente.
5. Teste datasource, segurança, logging, classloader e deployment.
6. Só depois atualize Maven e APIs de build compatíveis com `javax`.

Se não existir uma combinação intermediária suportável ou se a aplicação não
puder ser executada com segurança nela, mantenha o estado apenas como gate de
engenharia e não como destino de produção.

### Etapa 3 — modernizar dependências antes do salto Jakarta

Para cada dependência, escolha uma das decisões abaixo e execute uma mudança
por vez:

| Situação | Decisão recomendada |
| --- | --- |
| existe versão mantida compatível com o gate atual | atualizar e testar isoladamente |
| a API passou a ser fornecida pelo JDK ou servidor | remover a duplicata e auditar o WAR |
| a biblioteca está abandonada, mas o contrato é simples | criar teste/fachada e substituir por API padrão |
| a atualização exige `jakarta.*` | adiar explicitamente para o gate Jakarta |
| a biblioteca está espalhada por toda a aplicação | encapsular primeiro; evitar reescrita simultânea |
| não há substituição ou suporte aceitável | registrar bloqueio e reavaliar o destino |

Use análise de transitivas e inspeção de bytecode, não apenas dependências
diretas. Qualifique novamente XML, logging, JDBC e persistência depois de cada
grupo coerente.

### Etapa 4 — migrar servidor e Jakarta

1. Tente implantar o último WAR `javax` no servidor Jakarta e capture a falha.
2. Crie um perfil de build explícito para a plataforma Jakarta.
3. Migre imports, descritores, JSP/JSTL, TLD e bibliotecas web.
4. Preserve `javax.*` pertencente ao Java SE.
5. Substitua bibliotecas sem caminho Jakarta por mecanismos padrão ou fachadas.
6. Recrie driver, datasource, logging e segurança na configuração do novo
   servidor.
7. Execute contratos externos e auditoria do WAR em cada entrega.

Se a aplicação for EAR, valide classloading, ordem de módulos, bibliotecas
compartilhadas e um SCI por módulo web. Se usar EJB, JMS, JTA, CDI, JSF,
WebServices ou segurança específica do servidor, crie gates próprios antes de
considerar a migração equivalente à deste laboratório.

### Etapa 5 — qualificar a JVM final

Depois de aprovar servidor e Jakarta em uma JVM intermediária conhecida, troque
somente a JVM para a versão final. Verifique:

- toolchain Maven, plugins e `--release`;
- bytecode e APIs-alvo;
- opções de JVM removidas ou alteradas;
- reflexão, serialização, criptografia e encoding;
- agentes de observabilidade e bibliotecas nativas;
- consumo de memória, GC, threads e tempos de inicialização;
- contratos H2 e Oracle com o mesmo WAR.

Fixe uma distribuição específica, origem, licença e checksum. Não use `latest`
como referência de produção.

### Etapa 6 — ensaio e implantação em produção

Use instalações Blue e Green independentes. Preserve o Blue durante a janela,
publique o Green sem tráfego e execute os gates de artefato, runtime,
datasource, contratos, Oracle, segurança e observabilidade.

Antes do corte:

- ensaie rollback e cronometre o retorno;
- confirme compatibilidade do schema nas duas versões;
- defina quiescência de escrita, sessões, jobs, filas e uploads;
- estabeleça métricas e limites objetivos de go/no-go;
- proteja os dados com procedimento aprovado pelo DBA;
- registre responsáveis, horários e comunicação.

Depois do corte, valide um canário ou uma transação controlada, compare métricas
e mantenha o Blue disponível durante a estabilização. Se houver rollback,
interrompa novas escritas antes de retornar tráfego e reconcilie dados com o
DBA. Não restaure o banco cegamente.

O [roteiro blue/green da fase 2](phase2-real-application-migration-runbook.md)
detalha papéis, janela, go/no-go e rollback e pode ser adaptado também ao corte
final.

## Critérios recomendados para cada gate real

Um gate somente deve ser considerado verde quando possuir:

- commit integrado e artefato imutável com checksum;
- build reproduzível a partir de checkout limpo;
- runtime e configuração identificados por versão;
- contratos funcionais e negativos aprovados;
- qualificação no banco oficial quando persistência for afetada;
- árvore de dependências e conteúdo do WAR auditados;
- verificação de segredos, portas, licenças e componentes EOL;
- evidência sanitizada, limitações e cenários não executados;
- procedimento de retorno ao último estado verde;
- aceite dos responsáveis pelo risco alterado naquele gate.

## O que reutilizar deste repositório

| Necessidade na aplicação real | Referência do laboratório |
| --- | --- |
| preparar e diagnosticar versões | [preparação do ambiente](environment-setup.md) e `scripts/doctor.sh` |
| definir entregas incrementais | [checkpoints](checkpoints.md) e [fluxo GitHub](github-workflow.md) |
| criar contratos independentes do WAR | `contract-tests/` e baseline `migration/baselines/01-legacy/` |
| catalogar falhas e correções | [catálogo de incompatibilidades](../migration/incompatibility-catalog.md) |
| separar H2 de Oracle | [diferenças H2/Oracle](h2-oracle-differences.md) |
| revisar dependências | [matriz de dependências](cp-3a-dependency-matrix.md) |
| migrar namespace e descritores | [CP-3F — Jakarta](cp-3f-jakarta-namespaces.md) |
| substituir bibliotecas web | [CP-3G — substituições web](cp-3g-web-substitutions.md) |
| planejar corte e rollback | [roteiro para aplicação real](phase2-real-application-migration-runbook.md) |
| consultar provas finais | [relatório consolidado CP-3K](evidence/CP-3K.md) |

Os scripts devem ser usados como referência e adaptados à topologia, aos
controles e ao domínio da organização. Eles não devem ser apontados diretamente
para produção sem revisão.

## Conclusão

O laboratório demonstrou que uma aplicação Java 7/WildFly 9 pode evoluir até
OpenJDK 25/WildFly 41/Jakarta EE 11 preservando seu contrato funcional, desde
que a mudança seja tratada como uma sequência de estados verdes e não como uma
única atualização de versões.

O resultado mais reutilizável não é uma versão específica de biblioteca. É a
disciplina de preservar uma baseline, capturar falhas naturais, isolar
variáveis, auditar o artefato efetivo, qualificar no banco oficial e manter
rollback e evidências em cada gate. Em uma aplicação real, as versões e a
quantidade de gates podem mudar; esses critérios não deveriam mudar.

Esta conclusão registra o estado aprovado pelas atividades 3.51 a 3.55. A PR
#30 encerra o CP-3K pelo commit squash `checkpoint(CP-3K): complete final
destination`, e a tag `migration/03-final` preserva o terceiro checkpoint
público da mesma aplicação.
