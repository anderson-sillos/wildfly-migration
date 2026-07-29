# Laboratório de migração Java Web

Este repositório acompanha, em uma única linha evolutiva, a migração reproduzível
de uma aplicação Java 7/WildFly 9 para Java 25/WildFly 41/Jakarta EE 11. O
objetivo é expor incompatibilidades reais, aplicar correções pequenas e manter
cada entrega validável e reversível.

Repositório GitHub: <https://github.com/anderson-sillos/wildfly-migration>

Os checkpoints da fase 1 estão concluídos e preservados pela tag
`migration/01-legacy-baseline`. A árvore única `app/` está agora no
**CP-2A — Java 8 no WildFly 9**, mantendo as dependências, os pacotes `javax`,
os perfis H2/Oracle e o contrato funcional do baseline.

## Fases públicas

| Fase | Runtime aprovado | Tag de fechamento |
| --- | --- | --- |
| 1. Baseline legado | Java 7u80, WildFly 9.0.2, Java EE `javax` | `migration/01-legacy-baseline` |
| 2. Modernização de baixo impacto | Java 8, WildFly 26.1.3, EE 8 `javax` | `migration/02-java8-wildfly26` |
| 3. Destino final | OpenJDK 25, WildFly 41.0.0.Final comunitário, Jakarta EE 11 | `migration/03-final` |

Java 17/WildFly 26 e Java 21/WildFly 41 são gates técnicos internos da fase 3,
não fases adicionais.

## Começar

1. Abra o [índice da documentação](docs/README.md).
2. Leia [a preparação do ambiente](docs/environment-setup.md).
3. Para executar a aplicação, siga o
   [runbook legado](docs/legacy-application-runbook.md).
4. Para reproduzir a fase 1, siga
   [o fechamento do baseline legado](docs/legacy-baseline-reproduction.md).
5. Para executar o estado atual, siga
   [o CP-2A no Java 8/WildFly 9](docs/cp-2a-java8-wildfly9.md).
6. Para contribuir, consulte [o fluxo GitHub](docs/github-workflow.md).

No primeiro checkout:

1. Configure sua identidade Git e autentique a GitHub CLI.
2. Copie `.env.example` para `.env` sem inserir valores no arquivo de exemplo.
3. Execute:

```bash
./scripts/doctor.sh CP-1A
```

O comando falha de forma explícita enquanto identidade Git, autenticação ou
`origin` não estiverem configurados. Pré-requisitos futuros aparecem como
“não exigido”.

## Executar a aplicação no CP-2A

O [runbook do CP-2A](docs/cp-2a-java8-wildfly9.md) documenta a versão exata e
a URL de origem do JDK, diagnóstico, build, H2, Oracle, testes e rollback.

O modo manual provisiona uma cópia temporária do WildFly e mantém a aplicação
ativa em loopback até `Ctrl+C`:

```bash
./scripts/smoke-wildfly9-datasource.sh \
  --java 8 \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --manual
```

Use `--profile oracle` somente no host autorizado e depois da aprovação do
schema. Consulte também [CONTRIBUTING.md](CONTRIBUTING.md) e
[SECURITY.md](SECURITY.md).

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
