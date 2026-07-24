# Laboratório de migração Java Web

Este repositório acompanha, em uma única linha evolutiva, a migração reproduzível
de uma aplicação Java 7/WildFly 9 para Java 25/WildFly 41/Jakarta EE 11. O
objetivo é expor incompatibilidades reais, aplicar correções pequenas e manter
cada entrega validável e reversível.

Repositório GitHub: <https://github.com/anderson-sillos/wildfly-migration>

O trabalho está no checkpoint **CP-1A — Repositório GitHub e ambiente**. A árvore
da aplicação ainda não existe por decisão de projeto: primeiro são estabelecidos
o repositório, as verificações, a documentação e o diagnóstico do ambiente.

## Fases públicas

| Fase | Runtime aprovado | Tag de fechamento |
| --- | --- | --- |
| 1. Baseline legado | Java 7u80, WildFly 9.0.2, Java EE `javax` | `migration/01-legacy-baseline` |
| 2. Modernização de baixo impacto | Java 8, WildFly 26.1.3, EE 8 `javax` | `migration/02-java8-wildfly26` |
| 3. Destino final | OpenJDK 25, WildFly 41.0.0.Final comunitário, Jakarta EE 11 | `migration/03-final` |

Java 17/WildFly 26 e Java 21/WildFly 41 são gates técnicos internos da fase 3,
não fases adicionais.

## Começo rápido do CP-1A

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

Antes de contribuir, consulte [o fluxo GitHub](docs/github-workflow.md),
[os checkpoints](docs/checkpoints.md), [CONTRIBUTING.md](CONTRIBUTING.md) e
[SECURITY.md](SECURITY.md).

## Regras de segurança

- Java 7u80, drivers Oracle, credenciais, wallets e arquivos de runtime não são
  versionados nem publicados como artefatos.
- WildFly 9 e todo o ambiente legado ficam restritos a loopback ou rede interna.
- O destino final usa uma distribuição OpenJDK e o WildFly comunitário open
  source; Oracle JDK e JBoss EAP não são dependências do destino.
- A configuração real fica em `.env` ou no mecanismo de secrets do executor.

O planejamento executável está em
`openspec/changes/create-java-web-migration-lab/`.
