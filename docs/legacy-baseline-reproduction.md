# Reprodução do baseline legado

Este procedimento fecha a fase 1 a partir de um checkout limpo. O runbook
continua sendo a fonte dos testes manuais; esta página define a sequência
mínima e os critérios para reproduzir o artefato congelado e suas duas trilhas
de evidência.

## 1. Selecionar um estado imutável

Depois da publicação da fase 1:

```bash
git clone https://github.com/anderson-sillos/wildfly-migration.git
cd wildfly-migration
git switch --detach migration/01-legacy-baseline
git status --short
```

Durante a revisão do `CP-1G`, use um clone limpo do commit exato do pull
request. O resultado de `git status --short` deve ficar vazio antes e depois
da validação, exceto por derivados ignorados em `app/target/`.

## 2. Preparar componentes externos

Siga [Preparação do ambiente](environment-setup.md), fornecendo runtimes e
drivers fora do checkout. Copie `.env.example` para `.env` e preencha somente
os caminhos e segredos exigidos. O perfil é sempre escolhido pela linha de
comando; ele não fica no `.env`.

O manifesto congelado fica em
[`migration/baselines/01-legacy/`](../migration/baselines/01-legacy/). Confira:

- Oracle JDK 7u80, Maven 3.8.9 e WildFly 9.0.2.Final para
  `oracle-qualified`;
- Zulu OpenJDK 7u352, Maven 3.8.9, WildFly 9.0.2.Final e H2 1.4.200 para
  `portable-ci`;
- `ojdbc7` 12.1.0.2.0 externo somente para Oracle;
- checksums, origem e licença de cada componente;
- bind `127.0.0.1` e duas portas locais livres.

Nenhum binário externo, `.env`, URL JDBC ou credencial pode ser copiado para o
checkout.

## 3. Executar a trilha portátil

```bash
./scripts/doctor.sh CP-1G --profile ci-h2 --env .env
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json
```

O resultado deve registrar `portable-ci`, 14 cenários aprovados e o SHA-256
congelado do WAR. H2 comprova somente o contrato comum e as diferenças
explicitamente portáveis.

## 4. Executar a qualificação Oracle

Na rede interna autorizada:

```bash
./scripts/doctor.sh CP-1G --profile oracle --env .env
./scripts/oracle-lab-schema.sh inspect --env .env
./scripts/oracle-lab-schema.sh apply --env .env
./scripts/oracle-lab-schema.sh verify --env .env
./scripts/build-cp-1d.sh --profile oracle --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/oracle.json
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/oracle.json
```

O `verify` exige Oracle 19c RU `19.3.0.0.0`, os dois pares de objetos `LAB_*`
e todos os valores normalizados do seed `LAB-0001`. O resultado deve registrar
`oracle-qualified` com os mesmos 14 cenários e o mesmo WAR da trilha H2.

## 5. Aprovar o baseline

Confira:

```bash
sha256sum app/target/wildfly-migration.war \
  app/target/dependency-tree.txt
git status --short
```

Os valores devem corresponder a `baseline.properties`. O validador também
compara as 24 dependências Maven, as 20 entradas reais de `WEB-INF/lib`, as
APIs `provided`, o contrato normalizado e a ausência de configuração sensível
nos relatórios.

O WildFly temporário deve publicar HTTP e management somente em loopback e
encerrar ao final. Não publique `server.log` bruto do perfil Oracle.

## 6. Limpeza

- H2: o banco em memória e o runtime temporário desaparecem no stop;
- Oracle: `cleanup-smokes` remove somente `LAB-SMOKE-*`;
- Maven: `app/target/` é derivado, ignorado e recriado pelo próximo build;
- dados `MANUAL-*`, objetos e seed Oracle permanecem até uma decisão explícita.

Para limpeza Oracle manual e destrutiva, siga o processo protegido do
[runbook](legacy-application-runbook.md); o laboratório nunca executa
`DROP USER ... CASCADE`.

## 7. Rollback

Antes da tag, reverta o futuro squash do `CP-1G` por um novo pull request para
restaurar o commit verde do `CP-1F`. Depois da tag, nunca mova nem sobrescreva
`migration/01-legacy-baseline`: crie um commit corretivo e uma nova evidência.

O rollback do código não executa `rollback.sql`, não remove o schema Oracle e
não apaga componentes externos. A fase 2 sempre começa materializando a tag e
tentando o WAR anterior no runtime seguinte antes de qualquer correção.
