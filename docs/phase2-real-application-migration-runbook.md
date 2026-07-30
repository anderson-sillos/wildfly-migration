# Roteiro da fase 2 para uma aplicação real

## Objetivo e limites

Este roteiro adapta a modernização de baixo impacto comprovada pelo
laboratório para uma aplicação real: Java 7/WildFly 9 para Java 8/WildFly
26.1.3, Jakarta EE 8 com pacotes `javax.*` e Maven 3.9.16. Ele organiza
preparação, janela de transição, implantação blue/green, verificações,
go/no-go e rollback.

Os scripts do laboratório não devem ser executados diretamente em produção.
Eles são referências para criar automações equivalentes dentro dos controles
da organização. O laboratório não valida carga, cluster, disaster recovery,
procedures, tipos Oracle proprietários nem integrações que não estejam no seu
contrato reduzido.

O [manifesto da fase 2](../migration/baselines/02-java8-wildfly26/) é a
referência técnica. Antes de aplicar o roteiro, substitua cada versão,
dependência, teste e limitação pelos valores observados na aplicação real.

## Princípios de segurança da mudança

- Não atualize uma instalação existente do WildFly in-place.
- Preserve o ambiente Blue executável até o fim da estabilização.
- Prepare o Green em diretório, serviço e configuração independentes.
- Mantenha drivers JDBC e credenciais fora do WAR e do repositório.
- Não use H2 para decidir compatibilidade com o Oracle de produção.
- Não permita dois grupos de nós escrevendo simultaneamente sem comprovar
  compatibilidade transacional, de schema e de regras de negócio.
- Não restaure o banco cegamente durante um rollback; alterações confirmadas
  depois do corte podem ser dados válidos que precisam ser conciliados.

## Papéis e autorizações

| Papel | Responsabilidade mínima |
| --- | --- |
| responsável pela mudança | coordena janela, checklist, go/no-go e registro da decisão |
| equipe da aplicação | build, contratos, logs, integrações e validação funcional |
| equipe de plataforma | Java, WildFly, balanceador, observabilidade e retorno de tráfego |
| DBA Oracle | restore point ou backup aprovado, pool, sessões, locks e validação dos dados |
| segurança | segredos, certificados, exposição de portas e dependências conhecidas |
| representante de negócio | aprova fluxos críticos e critérios de impacto |

Cada papel deve ter um titular e um substituto identificados no registro da
mudança. O acesso necessário precisa ser testado antes da janela.

## Pré-condições obrigatórias

1. Congele uma revisão da aplicação antiga que possa ser reconstruída e
   relacione commit, artefato implantado e checksum.
2. Catalogue Java, Maven, plugins, WildFly, módulos, drivers, datasources,
   propriedades, system properties, certificados, filas, jobs, integrações,
   diretórios de upload e parâmetros de JVM efetivamente usados.
3. Crie contratos externos para os fluxos críticos sem importar classes do
   WAR. Normalize somente valores não funcionais.
4. Execute esses contratos no Blue e registre a baseline funcional e Oracle.
5. Confirme que a fase 2 não exige DDL incompatível. Qualquer mudança de
   schema deve ter plano próprio de compatibilidade expand/contract.
6. Defina com o DBA o mecanismo recuperável de dados, o tempo de retenção e o
   procedimento de reconciliação. Um restore point não autoriza restauração
   automática.
7. Confirme como sessões HTTP, uploads, arquivos temporários, caches, jobs e
   mensagens serão tratados durante a troca de nós.
8. Armazene o WAR, a distribuição de runtime e seus checksums em repositório
   de artefatos controlado. Nunca dependa de uma referência flutuante.
9. Aprove os riscos equivalentes às limitações conhecidas do
   `known-limitations.tsv`, especialmente WildFly 26 EOL, `ojdbc7`, Log4j 1,
   Tiles e demais bibliotecas legadas.
10. Faça ao menos um ensaio integral fora da produção com dados
    representativos e sanitizados.

Se uma pré-condição não for comprovada, a decisão é `no-go`.

## Topologia blue/green

| Elemento | Blue | Green |
| --- | --- | --- |
| JVM | Java 7 aprovado atualmente | Java 8 fixado e validado |
| servidor | WildFly 9 atual | nova instalação WildFly 26.1.3 |
| aplicação | WAR atualmente aprovado | WAR recompilado e auditado para Java 8 |
| configuração | exportada como evidência | recriada de forma declarativa e revisada |
| datasource | JNDI usado atualmente | mesmo contrato `java:/jdbc/MigrationDS` |
| tráfego | recebe produção antes do corte | sem tráfego ou somente canário autorizado |
| rollback | permanece disponível | é isolado, não sobrescreve o Blue |

O ensaio do Green usa schema ou conjunto de dados descartável. Na produção,
Blue e Green podem apontar para o mesmo schema somente quando:

- o DDL permanece retrocompatível;
- as duas versões leem os registros produzidos pela outra;
- sequences, triggers, jobs e locks não entram em conflito;
- uploads e outros efeitos fora do banco são compartilhados ou replicados;
- a equipe aprovou explicitamente a concorrência.

Mesmo nessas condições, o corte padrão usa quiescência de escrita: o Blue é
drenado ou colocado em modo somente leitura antes de liberar escrita no
Green. Isso reduz a quantidade de dados a reconciliar se houver rollback.

## Preparação do Green

1. Instale Java 8 e WildFly 26 em caminhos novos e valide versão, distribuição,
   licença e checksum.
2. Crie um `JBOSS_BASE_DIR` ou serviço separado. Não copie todo o
   `standalone.xml` antigo sobre a nova distribuição.
3. Recrie módulos, driver, datasource, pool, segurança, TLS, logging e system
   properties por configuração declarativa revisada.
4. Publique apenas as interfaces e portas necessárias. Management não deve
   ficar exposto a redes não autorizadas.
5. Forneça segredos pelo mecanismo corporativo e confira que logs e dumps não
   os reproduzem.
6. Implante o WAR por checksum, confirme o deployment e teste
   `java:/jdbc/MigrationDS` pelo pool do WildFly.
7. Mantenha jobs agendados, consumidores e outras ações com efeito externo
   desabilitados até a autorização do corte.
8. Integre logs, métricas, traces e alertas antes de receber tráfego.

## Verificações antes da janela

| Gate | Evidência mínima para aprovação |
| --- | --- |
| artefato | commit, checksum do WAR, árvore Maven e conteúdo de `WEB-INF/lib` correspondentes |
| runtime | Java 8 e WildFly 26 detectados, parâmetros revisados e nenhuma opção removida |
| empacotamento | APIs do contêiner, H2 e driver Oracle ausentes do WAR |
| datasource | driver esperado, pool saudável, validação de conexão e JNDI correto |
| contrato | fluxos críticos equivalentes ao Blue em ambiente controlado |
| Oracle | commit, rollback, sequences, timestamps, LOBs e SQL específico realmente utilizado |
| integrações | endpoints, certificados, filas, jobs, arquivos e timeouts verificados |
| segurança | portas, permissões, segredos e dependências excepcionadas aprovados |
| operação | dashboards, alertas, logs correlacionados e contatos de plantão disponíveis |
| rollback | retorno do balanceador e inicialização do Blue ensaiados e cronometrados |

O H2 `portable-ci` pode fornecer feedback de aplicação e JNDI, mas H2 nunca qualifica Oracle.
O gate Oracle exige a qualificação na rede autorizada. Um resultado portátil
nunca promove automaticamente a mudança para produção.

## Janela de transição

| Momento | Ação e critério |
| --- | --- |
| T-30 dias | fechar inventário, baseline, dependências, riscos e responsáveis |
| T-7 dias | concluir ensaio blue/green, teste Oracle e ensaio de rollback |
| T-24 horas | congelar mudanças concorrentes e confirmar artefatos e backups |
| T-60 minutos | executar checklist, testar acessos e registrar decisão preliminar |
| T-15 minutos | iniciar ou revalidar Green sem liberar escrita de produção |
| T0 | obter go, drenar Blue, estabelecer quiescência e registrar marcador de dados |
| T+5 minutos | direcionar canário permitido ou efetuar troca atômica de tráfego |
| T+30 minutos | concluir contratos não destrutivos, validação de negócio e métricas |
| T+120 minutos | encerrar janela técnica ou acionar rollback pelos critérios definidos |
| T+1 dia útil | revisar incidentes, evidências, capacidade e pendências da estabilização |

Os tempos são um modelo e precisam ser calibrados pelo ensaio. O registro da
mudança deve indicar horários absolutos, timezone, responsáveis e duração
máxima tolerada de indisponibilidade.

## Decisão go/no-go

O responsável pela mudança só declara `go` quando:

- Blue está saudável e recuperável;
- Green passou em todos os gates aplicáveis;
- artefato, runtime e configuração correspondem ao que foi ensaiado;
- o DBA confirmou proteção e estado inicial dos dados;
- balanceador, observabilidade e acessos de rollback foram testados;
- não existe incidente ativo ou mudança concorrente relevante;
- aplicação, plataforma, DBA e negócio deram aceite registrado.

Qualquer ausência, divergência de checksum ou teste obrigatório reprovado
produz `no-go`; a janela é encerrada sem direcionar produção ao Green.

## Execução do corte

1. Registre horário, revisão, WAR, versões e participantes.
2. Suspenda novas implantações e mudanças de configuração.
3. Drene o Blue e interrompa novas escritas de forma controlada.
4. Aguarde requisições e transações em andamento; registre sessões, filas,
   jobs e marcador final de dados.
5. Revalide pool, deployment, health check e logs do Green.
6. Libere um canário somente se sessão, dados e efeitos externos suportarem
   tráfego dividido. Caso contrário, faça troca atômica.
7. Execute testes não destrutivos e uma transação controlada identificável.
8. Compare respostas, estado Oracle, erros, latência, pool, CPU, memória,
   threads, filas e integrações com os limites aprovados.
9. Registre o aceite de negócio e mantenha o Blue intacto durante a
   estabilização.

Não execute a suíte destrutiva do laboratório sobre dados reais. Criação,
alteração ou limpeza de registros deve usar casos controlados, prefixos e
autorizações próprias da aplicação.

## Critérios de rollback

Acione rollback quando ocorrer qualquer condição previamente quantificada,
incluindo:

- health check ou deployment instável;
- erro funcional em fluxo crítico;
- falha de autenticação, sessão, upload ou integração;
- erro Oracle, crescimento anormal do pool, lock ou transação parcial;
- divergência de dados entre contrato e estado persistido;
- taxa de erro, latência, CPU, memória ou fila além do limite;
- perda de observabilidade ou impossibilidade de diagnosticar a mudança;
- esgotamento do tempo máximo da janela.

Não prolongue investigação dentro da janela depois que um critério objetivo
for atingido.

## Procedimento de rollback

### 1. Antes de liberar tráfego

Interrompa o Green, preserve logs e evidências e encerre a janela. O Blue não
foi alterado e continua como estado de serviço.

### 2. Depois do corte, com dados retrocompatíveis

1. Impeça novas requisições e escritas no Green.
2. Aguarde transações em andamento e registre o último marcador confirmado.
3. Confirme com o DBA que o Blue consegue ler os registros produzidos pelo
   Green e que não existe migração de schema incompatível.
4. Retorne o roteamento ao Blue.
5. Reative jobs e consumidores uma única vez no lado selecionado.
6. Execute health checks, consultas de dados e fluxos críticos no Blue.
7. Preserve o Green isolado para investigação.

Esse é um rollback de tráfego e runtime; ele não implica restauração do banco.

### 3. Quando houver incompatibilidade ou corrupção de dados

Mantenha escrita suspensa e entregue a decisão ao DBA e ao responsável de
negócio. Identifique transações válidas depois do corte, dados afetados e
dependências externas. Use o procedimento corporativo de recuperação e
reconciliação aprovado antes da janela.

Nunca faça restauração cega do banco para acelerar o retorno: isso pode apagar
operações válidas realizadas depois do corte. Recuperação de dados é uma
mudança separada, com autorização e evidência próprias.

## Evidências da execução real

Registre sem segredos:

- identificador da mudança, PR, commit e checksum do WAR;
- versões e checksums de Java, Maven, WildFly e driver JDBC;
- versão completa do Oracle e inventário de patches disponível;
- hash ou versão da configuração declarativa, sem valores sensíveis;
- horários, timezone, responsáveis e decisões go/no-go;
- resultados de build, auditoria, contratos, Oracle e segurança;
- métricas antes, durante e depois do corte;
- marcador de dados, transações controladas e aceite de negócio;
- rollback ensaiado, executado ou não necessário;
- limitações aceitas e prazo para removê-las.

## Correspondência com o laboratório

| Laboratório | Aplicação real |
| --- | --- |
| `doctor.sh CP-2D` | diagnóstico corporativo de versões, configuração e pré-requisitos |
| `build-cp-2c.sh` | pipeline reprodutível que gera o WAR imutável |
| `validate-cp-2d-manifest.sh` | SBOM/inventário, checksum e auditoria do artefato |
| `qualify-cp-2d-h2.sh` | feedback portátil sem credenciais ou rede interna |
| `qualify-cp-2d-oracle.sh` | qualificação autorizada contra Oracle não produtivo representativo |
| contratos HTTP externos | testes funcionais e efeitos persistidos da aplicação real |
| `phase2-comparison.json` | relatório de equivalência entre Blue e Green |

## Conclusão da estabilização

O Green só se torna a nova referência depois do período definido de
estabilização, aceite de negócio e ausência de critérios de rollback. Depois
disso:

1. preserve artefatos e evidências imutáveis;
2. remova o Blue por mudança separada e recuperável;
3. revogue acessos temporários;
4. registre incidentes e diferenças do ensaio;
5. planeje os gates da fase 3 para eliminar as limitações aceitas.

WildFly 26, Java 8 e as bibliotecas legadas continuam sendo uma ponte. O
sucesso desta janela não os transforma no destino sustentável final.
