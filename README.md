# Laboratório de migração Java Web

Este repositório acompanha, em uma única linha evolutiva, a migração reproduzível
de uma aplicação Java 7/WildFly 9 para Java 25/WildFly 41/Jakarta EE 11. O
objetivo é expor incompatibilidades reais, aplicar correções pequenas e manter
cada entrega validável e reversível.

Repositório GitHub: <https://github.com/anderson-sillos/wildfly-migration>

Os checkpoints **CP-1A — Repositório GitHub e ambiente**, **CP-1B — Estrutura
e runtime legado**, **CP-1C — WAR e dependências legadas** e **CP-1D —
Fundação portátil H2 e qualificação Oracle** estão concluídos. A árvore única
`app/` gera um WAR Java 7 auditável com as dependências históricas, enquanto
runtimes, drivers e credenciais permanecem externos. O próximo incremento é o
**CP-1E — Fluxo web e persistência**.

## Fases públicas

| Fase | Runtime aprovado | Tag de fechamento |
| --- | --- | --- |
| 1. Baseline legado | Java 7u80, WildFly 9.0.2, Java EE `javax` | `migration/01-legacy-baseline` |
| 2. Modernização de baixo impacto | Java 8, WildFly 26.1.3, EE 8 `javax` | `migration/02-java8-wildfly26` |
| 3. Destino final | OpenJDK 25, WildFly 41.0.0.Final comunitário, Jakarta EE 11 | `migration/03-final` |

Java 17/WildFly 26 e Java 21/WildFly 41 são gates técnicos internos da fase 3,
não fases adicionais.

## Validar o bootstrap do CP-1A

1. Leia [a preparação do ambiente](docs/environment-setup.md).
2. Configure sua identidade Git e autentique a GitHub CLI.
3. Copie `.env.example` para `.env` sem inserir valores no arquivo de exemplo.
4. Execute:

```bash
./scripts/doctor.sh CP-1A
```

O comando deve falhar de forma explícita enquanto identidade Git, autenticação
GitHub ou `origin` ainda não estiverem configurados. Pré-requisitos de fases
futuras aparecem como “não exigido”.

Para validar o CP-1B depois de fornecer o runtime legado externo:

```bash
./scripts/validate-cp-1b.sh --release
./scripts/doctor.sh CP-1B --env .env
```

Para validar e construir o CP-1C:

```bash
./scripts/doctor.sh CP-1C --env .env
./scripts/validate-cp-1c.sh
./scripts/build-cp-1c.sh --env .env
```

No CP-1D, escolha o perfil sem misturar seus pré-requisitos:

```bash
./scripts/doctor.sh CP-1D --profile ci-h2 --env .env --ci
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/validate-cp-1d-h2.sh \
  --java-home /caminho/do/zulu7 \
  --h2-jar /caminho/do/h2-1.4.200.jar
./scripts/smoke-wildfly9-datasource.sh --profile ci-h2 --env .env

./scripts/doctor.sh CP-1D --profile oracle --env .env
./scripts/build-cp-1d.sh --profile oracle --env .env
./scripts/smoke-wildfly9-datasource.sh --profile oracle --env .env
```

`ci-h2` nunca produz qualificação Oracle; `oracle` depende do ambiente
autorizado na rede interna.

Durante a construção do CP-1E, a base MyBatis pode ser verificada
estaticamente ou, depois do build `ci-h2`, também de forma dinâmica:

```bash
./scripts/validate-cp-1e-persistence.sh
./scripts/validate-cp-1e-web.sh
./scripts/validate-cp-1e-persistence.sh \
  --java-home /caminho/do/zulu7 \
  --h2-jar /caminho/do/h2-1.4.200.jar
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war
```

O segundo comando executa criação, consulta, BLOB e rollback pelos mesmos
mappers do WAR. O último implanta o WAR e valida saúde, lista, criação,
detalhe, Tiles/TLD e sessão. A arquitetura está em
[persistência MyBatis](docs/mybatis-persistence.md).

Antes de contribuir, consulte [o fluxo GitHub](docs/github-workflow.md),
[os checkpoints](docs/checkpoints.md), [CONTRIBUTING.md](CONTRIBUTING.md) e
[SECURITY.md](SECURITY.md).

A responsabilidade de cada diretório e as regras da linha evolutiva única estão
em [estrutura do repositório](docs/repository-layout.md).

O fornecimento do Java 7/Maven 3.8.9/WildFly 9 está em
[runtime legado](runtime/legacy/README.md), e o domínio mínimo está em
[modelo legado](docs/legacy-domain-model.md).

A distinção entre Oracle JDK 7u80/Oracle 19c e Zulu OpenJDK 7u352/H2 está em
[seleção do runtime portátil](docs/cp-1d-runtime-selection.md).
As diferenças de schema e semântica estão na
[matriz H2/Oracle](docs/h2-oracle-differences.md).
A aprovação separada dos dois perfis e seu rollback estão na
[evidência do CP-1D](docs/evidence/CP-1D.md).
A evolução corrente do fluxo web e sua qualificação está na
[evidência do CP-1E](docs/evidence/CP-1E.md).
A verificação obrigatória antes de alterar o Oracle está em
[aprovação do schema do laboratório](docs/oracle-lab-schema.md).

A [preparação completa do ambiente](docs/environment-setup.md) contém a matriz
de componentes por checkpoint e os endereços oficiais das fases futuras.

## Regras de segurança

- Oracle JDK 7u80, drivers Oracle, credenciais, wallets e arquivos de runtime
  não são versionados nem publicados como artefatos; o Zulu Java 7 e o H2
  portáteis também são baixados externamente e validados por checksum.
- WildFly 9 e todo o ambiente legado ficam restritos a loopback ou rede interna.
- O destino final usa uma distribuição OpenJDK e o WildFly comunitário open
  source; Oracle JDK e JBoss EAP não são dependências do destino.
- A configuração real fica em `.env` ou no mecanismo de secrets do executor.

O planejamento executável está em
`openspec/changes/create-java-web-migration-lab/`.

## Licença

O código e a documentação originais deste projeto são licenciados sob a
**GNU Affero General Public License v3.0 somente** (`AGPL-3.0-only`), salvo
indicação explícita em contrário. Consulte [LICENSE](LICENSE).

Em resumo, versões modificadas disponibilizadas por rede também devem oferecer
aos usuários acesso ao código-fonte correspondente nos termos da AGPL. Este
resumo não substitui o texto integral da licença.

Copyright (C) 2026 Anderson Martins.

Dependências, distribuições, ferramentas e demais materiais de terceiros mantêm
suas próprias licenças. A licença deste projeto não relicencia OpenJDK, WildFly,
OpenSpec nem as bibliotecas usadas pelo laboratório.
