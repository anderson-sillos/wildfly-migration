# Codex handoff

Atualizado em 2026-07-28 durante o checkpoint `CP-1G`.

Este documento preserva o contexto operacional necessário para continuar o
laboratório em outra sessão do Codex. Ele não substitui o OpenSpec, o runbook
ou as evidências e não contém credenciais, URLs Oracle, endereços internos nem
conteúdo do `.env`.

## Objetivo e decisões consolidadas

- Repositório pessoal: `anderson-sillos/wildfly-migration`.
- Licença do projeto: `AGPL-3.0-only`.
- Identidade Git: `asillos@gmail.com`.
- Uma única árvore Maven `app/` evolui entre as fases; não existem
  `legacy-app` ou `modern-app`.
- Cada checkpoint usa branch `checkpoint/*`, PR, checks e squash identificável.
- Fases públicas:
  1. Java 7u80/WildFly 9.0.2;
  2. Java 8/WildFly 26.1.3/EE 8 `javax`;
  3. OpenJDK 25/WildFly 41 comunitário/Jakarta EE 11, com gates internos em
     Java 17 e Java 21.
- H2 em memória gera somente `portable-ci`; Oracle Database 19c RU 19.3 gera a
  qualificação oficial `oracle-qualified`.
- Ambos os perfis usam pool gerenciado pelo WildFly em
  `java:/jdbc/MigrationDS`. Drivers ficam fora do WAR.
- `.env` é local e ignorado. Nunca mostrar ou versionar seus valores.

## Estado atual

- Mudança OpenSpec: `create-java-web-migration-lab`.
- Branch: `checkpoint/cp-1g-complete-legacy-baseline`.
- HEAD qualificado:
  `ea94065e682193b5581abbb003c2ca0b05d3f188`.
- Commits do checkpoint:
  - `80e8fa1 feat(CP-1G): freeze legacy baseline manifests`;
  - `ea94065 fix(CP-1G): verify Oracle release update explicitly`.
- Último squash no `main`: `8ca6b1b`, fechamento do `CP-1F`.
- Tarefas OpenSpec: 1.31 a 1.34 concluídas; 1.35 permanece aberta até PR,
  CI, squash e tag.
- Progresso: 34 de 110 tarefas.

## Entrega preparada

`migration/baselines/01-legacy/` congela:

- 14 cenários normalizados;
- estado persistido Oracle e seed `LAB-0001`;
- sete componentes de runtime/teste;
- 24 dependências Maven com SHA-256 individual, quatro `provided` e 20 em
  `WEB-INF/lib`;
- WAR SHA-256
  `9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`;
- árvore Maven SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`.

O manifesto histórico do WildFly 9 foi corrigido de Apache-2.0 para
`LGPL-2.1-only`, conforme `LICENSE.txt` da distribuição efetivamente usada.
O `ojdbc7` externo foi identificado como 12.1.0.2.0 e fixado por checksum.

O catálogo `migration/incompatibilities.tsv` e
`migration/incompatibility-template.md` definem a captura desde a fase 2:
tentativa natural antes da correção, assinatura sanitizada, causa, correção
mínima, evidências antes/depois, regressão, aplicação real e rollback.

## Validações aprovadas

Sobre `ea94065`:

- `doctor CP-1G/ci-h2`: 98 OK;
- `doctor CP-1G/oracle`: 97 OK;
- todas as validações estáticas CP-1B a CP-1G: aprovadas;
- build Java 7/Maven 3.8.9 e auditoria: aprovados;
- H2 schema lifecycle e probe MyBatis: aprovados;
- WildFly 9/H2: 14/14, `portable-ci`;
- WildFly 9/Oracle: 14/14, `oracle-qualified`;
- pós-smoke Oracle: produto 19c, RU 19.3, objetos e seed aprovados;
- reprodução H2 a partir de worktree limpo: aprovada;
- H2 e Oracle produziram o mesmo WAR e relatórios ligados ao mesmo commit.

A primeira captura do RU tentou usar somente `DatabaseMetaData` e gerou falso
negativo. `INC-004` registra a correção: produto por metadata JDBC e RU por
`PRODUCT_COMPONENT_VERSION.VERSION_FULL`.

## Próximas ações

1. Registrar a consolidação da evidência, handoff e tarefas em commit.
2. Enviar a branch e abrir o PR do `CP-1G`.
3. Aguardar `repository-baseline` e `portable-ci`; atualizar a evidência com o
   run.
4. Se tudo permanecer verde, marcar 1.35, integrar por squash
   `checkpoint(CP-1G): complete legacy baseline` e criar a tag imutável
   `migration/01-legacy-baseline`.
5. Iniciar `CP-2A` tentando o baseline sem correção no Java 8/WildFly 9.

## Comandos de retomada

```bash
git status --short --branch
openspec status --change create-java-web-migration-lab --json
openspec instructions apply --change create-java-web-migration-lab --json
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json \
  --contract-result app/target/contract-results/oracle.json
```

Os relatórios em `app/target/contract-results/` são derivados locais. Somente
resultados sanitizados podem ser transcritos para `docs/evidence/CP-1G.md`.
