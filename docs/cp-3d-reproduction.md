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
