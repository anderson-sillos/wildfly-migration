# Evidência CP-1F — Integrações e contratos legados

## Escopo

- branch de entrega: `checkpoint/cp-1f-integrations-contracts`;
- pull request: `#12`;
- revisão funcional qualificada:
  `a90e419f1b1c13df226583bcacfc82056c77c9fd`;
- runtime: Java 7, Maven 3.8.9 e WildFly 9.0.2.Final;
- WAR auditado: 20 bibliotecas, bytecode Java 7 e SHA-256
  `9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`;
- nenhuma credencial, URL JDBC, identidade do schema, endereço interno ou
  conteúdo bruto de log integra esta evidência.

O checkpoint acrescenta ao fluxo aprovado no `CP-1E`:

- upload por Commons FileUpload 1.2.2, com limite, nome normalizado e metadados
  persistidos;
- importação XML por XMLBeans 2.3.0 e dom4j 1.6.1, com XSD, rejeição de XXE e
  expansão de entidades;
- validadores descobertos por Reflections 0.9.10 em ordem determinística;
- eventos Log4j 1.2.14 correlacionados e stack trace completo para falhas
  internas;
- suíte HTTP externa comum aos perfis H2 e Oracle, sem importar classes ou
  recursos internos do WAR.

## Correções reproduzidas

### Dependência opcional do Commons FileUpload

O primeiro empacotamento com Commons FileUpload 1.2.2 falhou porque a API
histórica utiliza Commons IO sem declará-la como dependência transitiva
obrigatória. O laboratório declara diretamente Commons IO 1.3.2 e registra a
incompatibilidade em
`migration/steps/CP-1F-commons-fileupload-commons-io.md`.

### Expressão regular do XSD no XMLBeans 2.3.0

O compilador histórico exigiu que o hífen do padrão do número de pedido fosse
escapado. A menor correção preservou o contrato funcional do XSD e foi
registrada em `migration/steps/CP-1F-xmlbeans-xsd-regex.md`.

### Regra de domínio depois do XSD

Uma fixture que atende ao XSD com status `APROVADO` é rejeitada pelo
`StatusInicialValidator`. O cenário prova que a descoberta por Reflections
executa os validadores `numero-formato`, `valor-monetario` e `status-inicial`
nessa ordem e que a rejeição não persiste `XML-VALIDATOR-0001`.

### Preservação da exceção no log

Falhas internas consumidas pelas fronteiras HTTP agora passam o `Throwable`
para `LOGGER.error` ou `LOGGER.warn`. Rejeições funcionais esperadas permanecem
sem stack trace. Quando o listener falha, a causa original é propagada ao
contêiner para evitar mensagens sem diagnóstico.

## Resultado `portable-ci`

O mesmo WAR foi executado com Java 7 portátil, WildFly 9 e H2 1.4.200 em
memória, sempre restrito a loopback.

O relatório sanitizado
`app/target/contract-results/ci-h2.json`, gerado localmente e não versionado,
registrou `portable-ci`, o commit qualificado, o checksum do WAR e os seguintes
14 cenários aprovados:

1. saúde;
2. listagem;
3. criação;
4. detalhe;
5. preferência de sessão;
6. upload válido;
7. limite de upload;
8. formulário XML;
9. XML válido;
10. XML inválido no XSD;
11. rejeição pelo validador descoberto;
12. XXE;
13. expansão de entidades;
14. estado persistido.

Esse resultado valida o contrato portátil, mas não declara compatibilidade com
Oracle.

## Resultado `oracle-qualified`

O Oracle Database 19c de referência permanece identificado como RU
`19.3.0.0.0`. Na revisão qualificada:

- o `doctor` aprovou a ferramenta, Java 7u80, Maven, WildFly, truststore,
  presença oculta das três variáveis Oracle e checksum do `ojdbc7`;
- o mesmo WAR usado no H2 foi implantado no WildFly 9;
- os mesmos 14 cenários foram aprovados pelo perfil `oracle`;
- o relatório sanitizado registrou `oracle-qualified`, commit, runtime e
  checksum, sem URL, host, serviço, usuário ou senha;
- os pedidos automáticos `LAB-SMOKE-*` foram removidos ao final;
- nenhuma limpeza destrutiva do schema ou da conta foi executada.

## Validação manual

Em 28 de julho de 2026, o operador confirmou a validação manual final:

- importação XML válida concluída;
- fixture `pedido-invalido-validador.xml` rejeitada com HTTP 400;
- log contendo a ordem dos três validadores e
  `reason=domain_validator`;
- pedido `XML-VALIDATOR-0001` ausente da listagem;
- stack traces disponíveis nas falhas internas testadas sem exibir valores
  sensíveis na resposta HTTP.

Também foram adicionadas tasks compartilhadas do VS Code para iniciar a
aplicação em H2 ou Oracle e acompanhar o `server.log` da única sessão manual
ativa. O arquivo `.vscode/settings.json` continua versionado com os runtimes do
workspace e análise nula automática.

## Validações executadas

```bash
./scripts/doctor.sh CP-1F --profile ci-h2 --env .env
./scripts/doctor.sh CP-1F --profile oracle --env .env
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/build-cp-1d.sh --profile oracle --env .env
./scripts/validate-cp-1e-persistence.sh
./scripts/validate-cp-1d-h2.sh
./scripts/validate-documentation.sh
./scripts/validate-cp-1f-upload.sh
./scripts/validate-cp-1f-xml.sh
./scripts/validate-cp-1f-discovery-logging.sh
./scripts/validate-cp-1f-contracts.sh
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json
./scripts/smoke-wildfly9-datasource.sh \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/oracle.json
```

Os dois relatórios registraram o commit
`a90e419f1b1c13df226583bcacfc82056c77c9fd`, o mesmo checksum de WAR e todos os
cenários como `passed`.

## Rollback

O último estado verde anterior é o commit squash do `CP-1E`, abreviado como
`c85f607`. O rollback Git deve ser feito por um novo pull request que reverta o
futuro squash do `CP-1F`, sem reescrever `main`.

No H2, encerrar o WildFly elimina o banco em memória. No Oracle,
`cleanup-smokes` remove somente dados automáticos cujo número começa por
`LAB-SMOKE-`; dados manuais e os objetos do schema permanecem.

O arquivo `app/src/main/resources/db/oracle/rollback.sql` remove
permanentemente somente as duas tabelas e duas sequences `LAB_*` e não foi
executado nesta validação. A conta Oracle só pode ser removida pelo DBA e isso
não é automatizado pelo laboratório.

## Limitações abertas

- H2 em modo Oracle não substitui a qualificação Oracle 19c.
- O inventário de patches Oracle `one-off` continua não fornecido.
- Java 7, WildFly 9, Log4j 1 e as demais bibliotecas históricas são EOL ou
  vulneráveis e permanecem restritos ao laboratório isolado.
- O resultado remoto do GitHub Actions será registrado depois do push da
  revisão de fechamento.
