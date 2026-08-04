# Reprodução e rollback do CP-3D

## Objetivo

Este roteiro reproduz o gate Java 17/WildFly 26.1.3 sobre a entrada da fase 2
(`migration/02-java8-wildfly26`). A mesma versão do WAR é exercitada nos 14
contratos do baseline legado, primeiro no H2 portátil e depois no Oracle 19c
qualificado. O CI remoto executa somente H2; o Oracle exige rede interna e
segredos fornecidos fora do repositório.

## Pré-requisitos

- checkout limpo e `.env` local conforme `docs/environment-setup.md`;
- Temurin OpenJDK 17.0.20+8, Maven 3.9.16 e WildFly Community 26.1.3.Final;
- H2 2.4.240 para `ci-h2`;
- `ojdbc17` 23.26.2.0.0 e acesso ao schema Oracle descartável para `oracle`.

O doctor valida origem, licença e checksum antes da execução:

```bash
./scripts/doctor.sh CP-3D --profile ci-h2 --env .env --non-interactive
./scripts/doctor.sh CP-3D --profile oracle --env .env --non-interactive
```

## Execução incremental

O build usa `--ide-rebuild` internamente. Ele cria `app/target/vscode-build` e
só publica o WAR ao final, evitando que o build automático do JDT misture
classes incompletas de `app/target` ao empacotamento.

```bash
MIGRATION_SOURCE_COMMIT="$(git rev-parse HEAD)" \
  ./scripts/qualify-cp-3d-h2.sh --env .env \
  --result-directory app/target/contract-results/cp3d --non-interactive
```

Depois que o H2 passar, execute a qualificação Oracle no mesmo checkout e no
mesmo diretório de resultados:

```bash
MIGRATION_SOURCE_COMMIT="$(git rev-parse HEAD)" \
  ./scripts/qualify-cp-3d-oracle.sh --env .env \
  --result-directory app/target/contract-results/cp3d --non-interactive
```

As qualificações geram os relatórios temporários dos 14 cenários, dos testes
MyBatis, logging, upload e descoberta. Nenhum segredo é gravado nos relatórios;
os dados `LAB-SMOKE-*` do Oracle são removidos ao final.

## Conferência do gate

Após registrar as evidências versionadas, execute:

```bash
./scripts/validate-cp-3d.sh
./scripts/validate-documentation.sh
./scripts/validate-repository-baseline.sh
```

O gate só pode ser aprovado quando H2 e Oracle tiverem o mesmo `sourceCommit`,
o mesmo checksum do WAR, 14/14 cenários `passed`, comparação aprovada com o
baseline e o driver `ojdbc17-23.26.2.0.0` no relatório Oracle.

## Rollback

O rollback funcional retorna ao baseline da fase 2 por um novo commit/PR, sem
alterar o schema Oracle:

```bash
git switch --detach migration/02-java8-wildfly26
./scripts/doctor.sh CP-2D --profile ci-h2 --env .env --non-interactive
```

Para retornar ao estado de desenvolvimento, faça checkout da branch do PR e
reexecute o gate. A referência de integração do CP-3C é o commit
`314109417c648ce9d32ab3824d24696ac7c83a94`; não se cria fase ou tag pública
para o CP-3D. O rollback não remove dados fora dos registros transitórios
`LAB-SMOKE-*`.

## Implantação equivalente em produção

Este gate não é um destino permanente de produção: WildFly 26.1.3 e as
exceções `javax` são uma ponte para separar a atualização da JVM da migração
Jakarta. Quando uma aplicação real precisar reproduzir essa etapa, trate-a
como uma implantação blue/green controlada:

1. congele o commit, o checksum do WAR e o manifesto do gate Java 17; prepare
   nós Green isolados com Temurin 17.0.20+8 e WildFly Community 26.1.3.Final;
2. configure no Green o mesmo `java:/jdbc/MigrationDS`, pool, validação de
   conexão e driver `ojdbc17` aprovados, sempre por configuração externa e sem
   empacotar o driver no WAR;
3. implante o WAR sem atualizar o WildFly existente *in-place*, execute
   health checks, contratos representativos, smoke de persistência e
   verificação de logs antes de permitir tráfego;
4. compare respostas, sessões, uploads, estado persistido, métricas e filas
   com o Blue. A decisão é `go` somente com contratos, Oracle, segurança,
   capacidade operacional e plano de retorno aprovados;
5. faça a troca gradual de tráfego, mantenha o Blue disponível para retorno e
   registre commit, WAR, runtime, datasource, janela e responsáveis.

Não execute DDL, migração destrutiva ou restauração cega do banco durante a
troca. O schema Oracle deve ser compatível com os dois lados; dados de teste e
registros transitórios devem ser identificados e limpos conforme a política da
aplicação real.

## Critérios e procedimento de rollback

Interrompa a promoção e retorne o tráfego ao Blue se houver erro de
implantação, divergência de contrato, falha de datasource, aumento de erros ou
perda de sessão/upload. Depois da comutação, faça o mesmo retorno se os
indicadores definidos na janela excederem seus limites. Preserve o Green
isolado para investigação, colete logs sem segredos e confirme a estabilidade
do Blue; não remova o schema nem apague dados de produção.

O rollback técnico do laboratório é o checkout de
`migration/02-java8-wildfly26`, seguido do `doctor` e da reprodução dos
contratos no runtime Java 8/WildFly 26.1.3. Em produção, o equivalente é
reprovisionar o artefato e o runtime do Blue previamente aprovados, validar o
mesmo JNDI e somente então reabrir o tráfego. O rollback não desfaz a
migração de dados nem altera Oracle por tentativa.

## Correspondência com o laboratório

Os comandos abaixo reproduzem os gates de decisão sem expor credenciais:

```bash
./scripts/doctor.sh CP-3D --profile ci-h2 --env .env --non-interactive
./scripts/qualify-cp-3d-h2.sh --env .env --non-interactive
./scripts/qualify-cp-3d-oracle.sh --env .env --non-interactive
./scripts/validate-cp-3d.sh
```

O CI hospedado comprova somente `portable-ci` com H2; a execução Oracle
separada produz `oracle-qualified` na rede interna. As evidências e o
rollback versionados em `migration/evidence/CP-3D/` são o registro do gate,
não uma autorização para ignorar controles da produção.
