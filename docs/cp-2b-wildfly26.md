# CP-2B — WildFly 26 no Java 8

Este checkpoint troca somente WildFly 9.0.2.Final por WildFly 26.1.3.Final.
Eclipse Temurin OpenJDK 8u492-b09, Maven 3.8.9, bytecode Java 8, dependências
legadas e pacotes `javax.*` permanecem inalterados.

## Entrada imutável

A entrada é o squash do CP-2A,
`bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`. O WAR aprovado possui:

- SHA-256:
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- bytecode Java 8 major `52`;
- 20 JARs em `WEB-INF/lib`;
- namespace `javax.*`.

## WildFly 26 fixado

Use a distribuição comunitária documentada em
[`runtime/phase2/java8-wildfly26/`](../runtime/phase2/java8-wildfly26/).
O endereço oficial, a licença, o checksum publicado e o SHA-256 calculado
estão no manifesto dessa pasta e em `.env.example`.

## Tentativa antes da correção

Foi criada uma base temporária a partir do `standalone.xml` original do
WildFly 26. O WAR aprovado foi copiado diretamente para `deployments/`, com o
mesmo checksum. Nenhum datasource, driver, módulo, ajuste de segurança ou
alteração de código foi aplicado.

O resultado natural foi:

- WildFly 26 iniciou com Java 8 e permaneceu acessível somente em loopback;
- o deployment foi marcado como `FAILED`;
- `/wildfly-migration/health` respondeu `404`;
- `java:/jdbc/MigrationDS` não existia;
- a causa-raiz foi `javax.naming.NameNotFoundException` durante o bootstrap
  do MyBatis;
- o servidor aceitou `log4j.properties`, mas emitiu `WFLYLOG0100` informando
  que esse suporte está depreciado.

Consulte a
[evidência CP-2B](evidence/CP-2B.md) e o cenário
[`INC-007`](../migration/steps/CP-2B-wildfly26-missing-datasource.md).

## Classificação antes da correção

A tarefa 2.7 separou os sinais observados:

- `INC-007`, bloqueante: a configuração original não publica
  `java:/jdbc/MigrationDS`;
- `INC-008`, não bloqueante: `log4j.properties` ainda é aceito, mas está
  depreciado; a biblioteca será preservada neste checkpoint e atualizada
  somente no gate planejado;
- `INC-009`, não bloqueante: a configuração padrão tenta gerar um keystore
  HTTPS, embora o laboratório precise somente de HTTP em loopback;
- classloader: nenhum `ClassNotFoundException`, `NoClassDefFoundError` ou
  `LinkageError` foi observado; os avisos opcionais de Tiles/Weld não
  justificam adicionar bibliotecas ao WAR.

A matriz completa está em
[`compatibility-observations.tsv`](../migration/evidence/CP-2B/compatibility-observations.tsv).
As tarefas 2.8 e 2.9 deverão resolver `INC-007` e `INC-009` e revalidar o
classloader depois que a aplicação estiver ativa.

## Runtime corrigido

O runtime cria uma cópia temporária do WildFly 26 e:

1. remove o listener HTTPS, o contexto SSL, o key manager e o keystore padrão
   que não fazem parte do contrato local;
2. mantém HTTP e management em loopback;
3. instala o módulo H2 1.4.200 ou `ojdbc7`, conforme o perfil;
4. aplica o arquivo CLI específico do modelo WildFly 26;
5. publica e testa `java:/jdbc/MigrationDS`;
6. implanta o WAR aprovado e executa os mesmos 14 contratos;
7. reprova `ClassNotFoundException`, `NoClassDefFoundError` ou `LinkageError`.

O modelo de gerenciamento revelou `INC-010`: `pool-name` não é aceito pelo
WildFly 26. Os perfis novos removem somente esse argumento; JNDI, pool,
validação, transação, URLs e schema permanecem equivalentes.

### H2 portátil

```bash
./scripts/doctor.sh CP-2B --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly26-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2b-ci-h2.json
```

### Oracle qualificado

```bash
./scripts/doctor.sh CP-2B --profile oracle --env .env
./scripts/oracle-lab-schema.sh verify \
  --java-home "$JAVA8_HOME" --env .env
./scripts/build-cp-2a.sh --profile oracle --env .env
./scripts/smoke-wildfly26-datasource.sh \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2b-oracle.json
```

O perfil continua selecionado pela linha de comando. H2 permanece
`portable-ci`; somente a segunda execução produz `oracle-qualified`.

## Teste manual

Acrescente `--manual` ao comando do perfil desejado. No VS Code, use
`Tasks: Run Task` e selecione uma das tarefas `CP-2B: iniciar...`. A tarefa
`CP-2B: acompanhar log do WildFly 26` encontra o log da sessão ativa.

## Rollback atual

A tentativa usa somente uma cópia temporária do runtime. Pare o processo e
descarte essa cópia; a instalação externa e o código permanecem inalterados.
Para retornar ao último checkpoint verde, use o commit
`bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`.
