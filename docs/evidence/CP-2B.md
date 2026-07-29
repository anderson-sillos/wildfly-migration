# Evidência CP-2B — WildFly 26 no Java 8

## Escopo

- estado verde de origem: CP-2A, commit
  `bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`;
- WAR de origem:
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- destino: Eclipse Temurin OpenJDK 8u492-b09 e WildFly comunitário
  26.1.3.Final;
- configuração de destino: `standalone.xml` original, sem datasource
  `MigrationDS`;
- alterações de código, POM, dependências e WAR antes da tentativa: nenhuma.

## Tentativa antes da correção

O WAR copiado para a base temporária preservou exatamente o SHA-256 aprovado
no CP-2A. O servidor confirmou `WildFly Full 26.1.3.Final`, iniciou em
loopback e manteve o processo em estado `running`, porém com erros de serviço.

O CLI retornou:

```text
wildfly-migration.war  FAILED
WFLYCTL0216: Management resource data-source=MigrationDS not found
```

O endpoint `/wildfly-migration/health` respondeu `404`, pois o contexto web
não ficou ativo. A assinatura determinante no log foi:

```text
javax.naming.NameNotFoundException:
jdbc/MigrationDS -- service jboss.naming.context.java.jdbc.MigrationDS
```

A aplicação converteu a falha em
`IllegalStateException: Datasource JNDI do laboratório não está disponível`;
nenhuma URL, credencial ou endereço Oracle foi registrado.

## Classificação das incompatibilidades

| Área | Resultado anterior à correção |
| --- | --- |
| Configuração | Bloqueante | O `standalone.xml` original inicia, mas contém somente `ExampleDS`; os recursos do laboratório não migram com a troca do binário. |
| Datasource | Bloqueante, `INC-007` | `java:/jdbc/MigrationDS` ausente impede o bootstrap MyBatis e deixa o deployment `FAILED`. |
| Segurança | Não bloqueante, `INC-009` | Elytron tenta gerar o keystore HTTPS padrão; a aplicação não possui `security-constraint`, `login-config` ou domínio próprio. O runtime do laboratório removerá o listener HTTPS desnecessário. |
| Logging | Não bloqueante, `INC-008` | `WFLYLOG0100`: `log4j.properties` foi aceito, porém seu suporte está depreciado. A remoção da biblioteca permanece adiada para o gate de dependências. |
| Classloader | Nenhuma quebra confirmada | Não houve `ClassNotFoundException`, `NoClassDefFoundError` ou `LinkageError`. Tiles avisou sobre factories opcionais de portlet e Weld sobre ausência de bean archive; não será incluído JAR nem `beans.xml` apenas para silenciar avisos. |

A classificação legível por máquina está em
[`compatibility-observations.tsv`](../../migration/evidence/CP-2B/compatibility-observations.tsv).
A falha JNDI limita a profundidade da observação do classloader; os contratos
das tarefas 2.8 e 2.9 deverão confirmar que nenhuma quebra aparece depois da
ativação do contexto.

Ao iniciar a correção, a aplicação direta do arquivo CLI do WildFly 9 revelou
`INC-010`: o WildFly 26 rejeita o argumento `pool-name` na operação
`data-source:add`. A correção mantém perfis próprios por servidor e remove
somente esse atributo redundante.

## Evidência legível por máquina

O registro sanitizado está em
[`before-deployment.properties`](../../migration/evidence/CP-2B/before-deployment.properties).
O log bruto permaneceu apenas na área temporária local e não foi versionado.

## Próxima correção

Provisionar os perfis H2 e Oracle no WildFly 26 sob
`java:/jdbc/MigrationDS`, preservando schema, código, namespace e WAR. A
correção foi implementada no commit
`5d1f6be20168909e8777a5f8a479e7d6b6d4a81a`.

## Depois da correção

O runtime corrigido criou uma cópia temporária da distribuição aprovada,
removeu somente os recursos HTTPS não usados, instalou o driver do perfil e
aplicou a CLI específica do WildFly 26. A instalação externa original não foi
modificada.

Os dois perfis produziram:

| Trilha | Perfil | Contratos | Pool | Resultado |
| --- | --- | ---: | --- | --- |
| `portable-ci` | H2 1.4.200 | 14/14 | aprovado | aprovado |
| `oracle-qualified` | Oracle 19c RU 19.3 / `ojdbc7` | 14/14 | aprovado | aprovado |

Ambas as execuções usaram o runtime `java8-wildfly26.1.3`, o commit
`5d1f6be20168909e8777a5f8a479e7d6b6d4a81a` e o mesmo WAR do CP-2A:
`bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`.

Os relatórios sanitizados estão em
[`contract-ci-h2.json`](../../migration/evidence/CP-2B/contract-ci-h2.json),
[`contract-oracle.json`](../../migration/evidence/CP-2B/contract-oracle.json)
e
[`after.properties`](../../migration/evidence/CP-2B/after.properties).

## CI hospedado

O PR
[#16](https://github.com/anderson-sillos/wildfly-migration/pull/16)
reproduziu a trilha portátil no GitHub Actions sem acesso ao Oracle interno.
A execução
[`30475883532`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30475883532)
aprovou `repository-baseline` em 15 segundos e `portable-ci` em 3 minutos e
45 segundos.

O job portátil baixou Java 8, Maven 3.8.9, WildFly 26.1.3 e H2 1.4.200 das
origens registradas, verificou seus checksums, construiu o WAR reproduzível,
publicou `java:/jdbc/MigrationDS`, executou os 14 contratos e preservou o
relatório sanitizado como artefato do workflow. Essa execução confirma a
reprodução fora da máquina que realizou a qualificação Oracle.

### Cache do runtime portátil

Os quatro arquivos de distribuição fixados são restaurados por
`actions/cache@v5` em uma área específica sob `runner.temp`, fora do checkout
Git. A chave inclui sistema operacional, arquitetura e o hash dos manifestos
que registram Java, Maven, WildFly e H2. Qualquer alteração nesses manifestos
cria uma chave nova.

Um `cache hit` evita somente os downloads externos. Os checksums SHA-256 são
revalidados em toda execução e a extração, o `doctor`, o build, o WAR, o
runtime temporário e os contratos continuam sendo recriados. Um segundo cache
contém somente `~/.m2/repository`, com chave exata derivada de sistema,
arquitetura, Maven 3.8.9 e `app/pom.xml`, sem chave parcial de restauração.
Ele não inclui `settings.xml`, credenciais, `app/target`, relatórios,
evidências ou configuração modificada do WildFly.

No cache miss do runtime, Maven Central é a origem primária do Maven 3.8.9 e
Apache Archive é o fallback. Os dois endereços entregaram localmente o mesmo
arquivo de 8.296.518 bytes e SHA-256
`3e4c68cdd70f96635e713f36c8fc3ea3182035245d3da2156576710ca0fe4b0c`.
O download usa arquivo parcial e só o promove ao cache depois de validar o
digest aprovado.

O primeiro uso, na tentativa 1 da execução
[`30477479488`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30477479488),
registrou `Cache not found`, baixou os quatro arquivos e gravou
330.748.197 bytes sob a chave
`cp-2b-runtime-archives-v1-Linux-X64-5bc79c15852d00395655eeca56c4039730dffc60746a4fc25d45999e4eba9fb2`.
O `portable-ci` concluiu em 2 minutos e 42 segundos.

A
[`tentativa 2`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30477479488/attempts/2)
restaurou exatamente essa chave, revalidou individualmente os quatro
SHA-256, não realizou downloads e aprovou todos os mesmos passos em 1 minuto
e 2 segundos. A economia observada foi de 1 minuto e 40 segundos, cerca de
62% do tempo do job portátil nessa comparação.

O aprimoramento seguinte criou a chave de runtime `v2` para comprovar a nova
origem e adicionou o cache Maven estrito. Na
[`tentativa 1`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30479982987/attempts/1),
ambos começaram vazios. Maven Central entregou e validou o Maven 3.8.9 em
aproximadamente 0,1 segundo; os quatro downloads e extrações terminaram em 6
segundos. O build Maven informou 19,468 segundos e o `portable-ci` completo
passou em 1 minuto e 4 segundos.

Essa tentativa gravou 330.748.175 bytes para o runtime e 28.626.190 bytes
para `~/.m2/repository`. A
[`tentativa 2`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30479982987/attempts/2)
restaurou as duas chaves, revalidou os quatro arquivos de runtime sem download
e executou o Maven em 2,158 segundos. O job completo passou em 39 segundos,
incluindo os mesmos 17 segundos do smoke WildFly e os mesmos 14 contratos.

Comparado ao cache miss anterior de 2 minutos e 42 segundos, o novo cache miss
economizou 1 minuto e 38 segundos, cerca de 60%. Comparado ao cache hit
anterior de 1 minuto e 2 segundos, o cache Maven reduziu mais 23 segundos,
cerca de 37%.

O cache criado em um PR pertence à referência temporária
`refs/pull/16/merge`, portanto comprova o reaproveitamento nas reexecuções
desse PR. A primeira execução posterior em `main` deverá criar o cache da
branch padrão; execuções seguintes poderão reutilizá-lo de acordo com as
regras de escopo do GitHub Actions.

O cache é uma otimização descartável e não constitui evidência de
compatibilidade. Em sua ausência ou expiração, o workflow volta a baixar das
origens registradas e produz o mesmo resultado após validar os checksums.

As actions auxiliares também foram alinhadas ao runtime Node 24:
`actions/checkout@v6`, `actions/cache@v5` e
`actions/upload-artifact@v6`.

### Execuções aplicáveis e concorrência

`repository-baseline` permanece em todos os pull requests. O job
`portable-ci` foi isolado em workflow próprio e é disparado quando mudam
`.env.example`, o próprio workflow, `app/`, `contract-tests/`,
`migration/baselines/`, `runtime/` ou `scripts/`. Alterações exclusivamente
documentais continuam sendo verificadas estaticamente, mas não recriam o
runtime portátil.

Ambos os workflows cancelam uma execução anterior ainda ativa quando um novo
commit é enviado à mesma referência. Essa regra reduz fila e consumo, sem
cancelar outro PR e sem alterar qualquer etapa do smoke WildFly ou dos 14
contratos.

## Conclusão comprovada

O CP-2B comprova que o mesmo binário aprovado no CP-2A pode ser executado no
WildFly 26.1.3.Final com Java 8, sem recompilar a aplicação e sem alterar POM,
dependências, bytecode, namespace `javax.*`, schema ou contrato funcional.

### Configuração não acompanha o binário do servidor

A tentativa anterior à correção demonstrou que substituir a instalação do
WildFly não transfere seus recursos gerenciados. O servidor iniciou, mas a
aplicação ficou indisponível porque `java:/jdbc/MigrationDS` não existia.

Isso comprova que datasource, driver, pool, validação e segredos externos
precisam ser inventariados e migrados explicitamente; copiar somente o WAR e
o novo servidor não produz um ambiente funcional.

### Migração mínima do runtime

A correção permaneceu fora da aplicação. Ela:

1. fixou a distribuição comunitária WildFly 26 por origem, licença e
   checksum;
2. criou uma cópia temporária reproduzível;
3. removeu apenas HTTPS e o keystore autogerado que não fazem parte do
   contrato local;
4. provisionou drivers e `java:/jdbc/MigrationDS` por perfil;
5. adaptou somente a diferença `pool-name` do modelo de gerenciamento.

A instalação externa continuou imutável e o rollback permanece o descarte da
cópia temporária.

### Equivalência funcional e persistência

Os mesmos 14 cenários do baseline passaram em H2 e Oracle. Foram exercitados
health, pedidos, sessão, upload, XML, validações negativas, MyBatis, pool e
estado persistido.

O H2 comprova apenas a trilha portátil. A execução separada no Oracle 19c RU
19.3 comprova que a configuração Oracle, o `ojdbc7`, o pool e os contratos
selecionados continuam funcionais no WildFly 26.

### Namespace, empacotamento e classloader preservados

O WAR manteve bytecode major `52`, SHA-256 idêntico e as bibliotecas legadas.
Não houve `ClassNotFoundException`, `NoClassDefFoundError` ou `LinkageError`
depois que o datasource permitiu ativar a aplicação. Nenhum JAR foi adicionado
para silenciar os avisos opcionais de Tiles ou Weld.

Isso isola a troca do WildFly das mudanças de EE, Maven e bibliotecas que
pertencem aos checkpoints seguintes.

### Logging permanece uma limitação conhecida

Log4j 1.2.14 continua ativo e o contrato de logs passou. O WildFly 26 emitiu
`WFLYLOG0100`, indicando que a configuração Log4j dentro do deployment está
depreciada, mas ainda funcional.

Foi documentada como alternativa retirar o arquivo do WAR e configurar o
logging no runtime sem trocar imediatamente a biblioteca. Essa alternativa
ainda não foi qualificada e não é apresentada como correção concluída. A
substituição da biblioteca permanece reservada ao gate de dependências.

### Limites da conclusão

O CP-2B não comprova alinhamento com EE 8, Maven 3.9.16 ou driver Oracle
moderno; esses itens começam no CP-2C ou na fase 3. Também não qualifica
autenticação, TLS, cluster, carga ou integrações externas ausentes do
laboratório.

WildFly 26 e Java 8 são uma ponte EOL reproduzível, não o destino final de
produção. A conclusão para uma aplicação real depende de repetir o inventário
e os contratos próprios do sistema.
