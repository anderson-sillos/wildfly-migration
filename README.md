# Laboratório de migração Java Web

Este repositório acompanha, em uma única linha evolutiva, a migração reproduzível
de uma aplicação Java 7/WildFly 9 para Java 25/WildFly 41/Jakarta EE 11. O
objetivo é expor incompatibilidades reais, aplicar correções pequenas e manter
cada entrega validável e reversível.

Repositório GitHub: <https://github.com/anderson-sillos/wildfly-migration>

Os checkpoints **CP-1A — Repositório GitHub e ambiente** e **CP-1B — Estrutura
e runtime legado** estão concluídos. A árvore única `app/`, o manifesto do
runtime, o modelo mínimo, o SQL Oracle, o XSD e os fixtures já existem. O
Oracle JDK 7u80 fornecido externamente, o Maven 3.8.9 e o WildFly 9.0.2.Final
foram aprovados por versão, origem, licença e checksum. O próximo incremento é
o **CP-1C — WAR e dependências legadas**; ainda não há `pom.xml`, WAR ou
dependências.

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

Antes de contribuir, consulte [o fluxo GitHub](docs/github-workflow.md),
[os checkpoints](docs/checkpoints.md), [CONTRIBUTING.md](CONTRIBUTING.md) e
[SECURITY.md](SECURITY.md).

A responsabilidade de cada diretório e as regras da linha evolutiva única estão
em [estrutura do repositório](docs/repository-layout.md).

O fornecimento do Java 7/Maven 3.8.9/WildFly 9 está em
[runtime legado](runtime/legacy/README.md), e o domínio mínimo está em
[modelo legado](docs/legacy-domain-model.md).

A [preparação completa do ambiente](docs/environment-setup.md) contém a matriz
de componentes por checkpoint e os endereços oficiais das fases futuras.

## Regras de segurança

- Java 7u80, drivers Oracle, credenciais, wallets e arquivos de runtime não são
  versionados nem publicados como artefatos.
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
