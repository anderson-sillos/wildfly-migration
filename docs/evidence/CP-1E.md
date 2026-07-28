# Evidência CP-1E — Fluxo web e persistência

## Escopo

- branch de entrega: `checkpoint/cp-1e-web-persistence`;
- pull request: `#11`;
- runtime legado: Oracle JDK 7u80, Maven 3.8.9 e WildFly 9.0.2.Final;
- contrato de banco comum: `java:/jdbc/MigrationDS`, transações JDBC locais
  delimitadas pelo MyBatis 3.4.5;
- aplicação: Servlets 2.4, JSP 2.0/JSTL 1.2, Tiles 2.1.4 e TLD 2.0;
- revisão funcional qualificada:
  `454ec833aecdef0e70f0a00b66fde63b7a7809ba`;
- WAR auditado nessa revisão: 19 bibliotecas, bytecode Java 7, SHA-256
  `60b09b60dc15e3a542a80fe05932fee1f92d9074cde6ed4198da554e1f6a6392`;
- nenhuma credencial, URL, nome de usuário, serviço interno ou binário
  proprietário integra esta evidência.

## Correções reproduzidas

### Implementação ausente do Tiles

Sintoma previsto: `tiles-api:2.1.4` contém o contrato, mas não a implementação
que inicializa o container e renderiza as tags JSP.

Menor correção aplicada: inclusão de `tiles-jsp:2.1.4`, preservando a versão
histórica. A árvore auditada passou a conter também `tiles-core`,
`tiles-servlet`, `commons-digester` e `commons-beanutils`, totalizando 19
bibliotecas em `WEB-INF/lib`.

### Binding padrão após remover o ExampleDS

Sintoma observado no primeiro deploy H2: o WildFly recusou a aplicação porque
`DefaultDataSource` ainda dependia de `java:jboss/datasources/ExampleDS`, já
removido pelo perfil.

Causa: criar `MigrationDS` não altera automaticamente o binding padrão do
subsistema Java EE.

Menor correção aplicada: o mesmo batch que remove `ExampleDS` e cria
`MigrationDS` agora aponta `ee/default-bindings.datasource` para
`java:/jdbc/MigrationDS`. O datasource explícito da aplicação não mudou.

## Resultado portátil H2

O fluxo foi aprovado no WildFly 9 restrito a loopback:

- bootstrap efêmero executado somente com
  `-Dmigration.bootstrap.h2=true` e recusado fora do produto H2;
- health confirmou JNDI, inicialização MyBatis e consulta;
- lista JSP/Tiles exibiu o seed `LAB-0001`;
- criação e detalhe persistiram um novo pedido;
- o TLD 2.0 executou um handler baseado em
  `javax.servlet.jsp.tagext.SimpleTagSupport`;
- um cookie de sessão preservou a mudança de `DETALHADO` para `COMPACTO`;
- todas as respostas passaram pelo filtro de UTF-8 e correlação;
- o H2 permaneceu em memória, sem listener, console ou credencial.

Esse resultado não declara compatibilidade Oracle.

## Resultado Oracle

O Oracle Database 19c de referência foi identificado como RU `19.3.0.0.0`.
Depois da confirmação do DBA de que a conta era um schema descartável e
exclusivo do laboratório:

- o `doctor` aprovou 66 verificações, sem falha ou aviso;
- a inspeção JDBC confirmou, sem revelar valores, identidade igual ao schema,
  PDB diferente de `CDB$ROOT`, quota limitada, ausência de papéis, exatamente
  `CREATE SESSION`, `CREATE TABLE` e `CREATE SEQUENCE` e nenhum objeto externo;
- `001_schema.sql` criou somente duas tabelas e duas sequences `LAB_*`;
- `002_seed.sql` criou exatamente um `LAB-0001`;
- o mesmo WAR aprovado no H2 passou por health, lista, criação, detalhe, Tiles,
  TLD e sessão no WildFly 9 com `ojdbc7`;
- pedidos transitórios `LAB-SMOKE-*` foram removidos ao final e uma verificação
  posterior confirmou que schema e seed permaneceram válidos;
- não foi executado `rollback.sql`, `DROP USER` nem qualquer DDL fora do
  conjunto `LAB_*`.

## Operação manual consolidada

O ciclo operacional foi centralizado em
`docs/legacy-application-runbook.md`, com índice em `docs/README.md`. O runbook
é a fonte única para diagnóstico, banco, build, start, URLs, casos manuais,
stop, limpeza e troubleshooting; documentos de instalação, arquitetura e
evidência passaram a apontar para ele em vez de repetir comandos.

A seleção `ci-h2`/`oracle` não é armazenada no `.env`. Todos os comandos
aplicáveis a partir do `CP-1D` recebem `--profile` explicitamente; o `doctor`
encerra com código 2 e diagnóstico objetivo quando esse argumento é omitido,
sem impedir que checkpoints anteriores ao CP-1D sejam diagnosticados.

Em 28 de julho de 2026, o modo `--manual` e o checklist publicado no runbook
foram concluídos pelo operador no perfil Oracle:

- o provisionamento e o smoke inicial foram aprovados;
- saúde/correlação, listagem, Tiles/TLD, criação, detalhe, preferência de sessão
  e erros controlados foram verificados manualmente;
- o processo permaneceu ativo e imprimiu URLs em loopback, o caminho temporário
  do `server.log`, um comando `tail -f` copiável e o alerta de segurança Oracle;
- o arquivo de log existiu durante a sessão sem que seu identificador temporário
  ou conteúdo bruto fossem incorporados a esta evidência;
- `/wildfly-migration/health` respondeu `status=UP`;
- `Ctrl+C` encerrou o servidor e removeu a cópia temporária do WildFly e o log;
- nenhum valor de conexão foi impresso e os objetos Oracle permaneceram.

## Validações

Na revisão funcional `454ec833aecdef0e70f0a00b66fde63b7a7809ba`, o WAR
`60b09b60dc15e3a542a80fe05932fee1f92d9074cde6ed4198da554e1f6a6392`
foi construído uma única vez no perfil `ci-h2`. O checksum foi conferido antes
e depois dos smokes H2 e Oracle, comprovando que as duas trilhas executaram
exatamente o mesmo artefato. Os resultados foram:

- `doctor` H2: 73 aprovados, nenhuma falha ou aviso;
- smoke H2: saúde, lista, criação, detalhe, TLD, sessão, JNDI e pool aprovados;
- `doctor` Oracle: 72 aprovados, nenhuma falha ou aviso;
- smoke Oracle: os mesmos casos, JNDI e pool aprovados;
- nenhum endereço interno, usuário, senha ou conteúdo bruto de log foi
  incorporado à evidência.

```bash
./scripts/doctor.sh CP-1E --profile oracle --env .env
./scripts/validate-cp-1b.sh --release
./scripts/validate-cp-1c.sh
./scripts/validate-cp-1d-selection.sh
./scripts/validate-cp-1d-profiles.sh
./scripts/validate-cp-1d-h2.sh
./scripts/validate-cp-1d-datasources.sh
./scripts/validate-cp-1e-persistence.sh
./scripts/validate-cp-1e-web.sh
./scripts/validate-documentation.sh
./scripts/build-cp-1d.sh --profile oracle --env .env
./scripts/oracle-lab-schema.sh inspect --env .env
./scripts/oracle-lab-schema.sh apply --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war
./scripts/oracle-lab-schema.sh verify --env .env
openspec validate create-java-web-migration-lab \
  --type change --strict --no-interactive
git diff --check
```

O job `portable-ci` executa build, auditoria, lifecycle H2, prova dinâmica
MyBatis e o smoke web no runner hospedado. Para a revisão funcional
`454ec833aecdef0e70f0a00b66fde63b7a7809ba`, a execução
[`30372169700`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30372169700)
foi aprovada em 28 de julho de 2026:

- `repository-baseline`: aprovado em 11 segundos;
- `portable-ci`: aprovado em 1 minuto e 48 segundos;
- nenhum secret, Oracle JDK, `ojdbc7` ou rota interna foi fornecido ao runner.

## Rollback

O rollback Git deve ser feito por um novo PR que reverta o futuro commit squash
do CP-1E, sem reescrever `main`.

No H2, encerrar o processo remove todo o banco em memória. No Oracle,
`cleanup-smokes` remove somente pedidos cujo número começa por
`LAB-SMOKE-`; ele não remove schema, seed ou objetos.

Para reiniciar os objetos Oracle, um responsável deve reconfirmar o schema e
então executar `app/src/main/resources/db/oracle/rollback.sql`. Esse script
remove permanentemente apenas `LAB_ANEXO`, `LAB_PEDIDO`, `LAB_ANEXO_SEQ` e
`LAB_PEDIDO_SEQ`. A conta Oracle só pode ser removida separadamente por um DBA,
com confirmação explícita do nome; isso não é automatizado pelo projeto.

## Limitações abertas

- H2 em modo Oracle continua sem substituir o Oracle 19c.
- O inventário de patches Oracle `one-off` não foi fornecido.
- Upload, XML, Reflections e Log4j entram no CP-1F.
- O schema Oracle descartável permanece ativo com os objetos e o seed para os
  próximos checkpoints; sua remoção é responsabilidade coordenada com o DBA.
