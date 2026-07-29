# Codex handoff

Atualizado em 2026-07-29 durante o checkpoint `CP-2A`.

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
- Branch: `checkpoint/cp-2a-java8-wildfly9`.
- Commit de implementação qualificado:
  `c76f42f4035ac08b13fca478f1d8e375190761b9`.
- Último commit revalidado pelo CI:
  `45caea0`.
- Commits do checkpoint:
  - `c76f42f feat(CP-2A): run application on Java 8`;
  - `d4cfef1 test(CP-2A): record Java 8 qualification evidence`;
  - `ed271a7 docs(CP-2A): update Codex handoff`;
  - `45caea0 docs(CP-2A): expand checkpoint conclusion`.
- Último squash no `main`: `a7c7b5b`, fechamento do `CP-1G`.
- Tag pública da fase 1:
  `migration/01-legacy-baseline`, apontando para `a7c7b5b`.
- Tarefas OpenSpec 2.1 a 2.5 concluídas no conteúdo do PR; o squash efetiva o
  encerramento no branch principal.
- Progresso preparado: 40 de 110 tarefas.

## Entrega CP-2A preparada

O CP-2A executou primeiro o WAR congelado Java 7, bytecode major 51 e SHA-256
`9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`
no Temurin Java 8/WildFly 9. Os 14 contratos H2 passaram sem recompilação.

As duas incompatibilidades naturais registradas são:

- `INC-005`: Maven Enforcer rejeitava Java 8 pela faixa `[1.7,1.8)`;
- `INC-006`: WildFly 9 enviava `-XX:MaxPermSize`, removida no Java 8.

O estado corrigido:

- usa Eclipse Temurin OpenJDK 8u492-b09, origem, licença e SHA-256 fixados;
- mantém Maven 3.8.9, WildFly 9.0.2.Final, dependências e `javax.*`;
- produz WAR bytecode major 52 com SHA-256
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- preserva as 24 dependências, os 20 JARs e a árvore Maven SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`;
- remove `MaxPermSize` somente da cópia temporária do WildFly usada no Java 8.
- registra a conclusão comprovada no próprio documento de evidência do CP-2A,
  sem criar um quadro paralelo para checkpoints pendentes.

## Validações aprovadas

Sobre `c76f42f`:

- `doctor CP-2A/ci-h2`: 107 OK;
- `doctor CP-2A/oracle`: 106 OK;
- todas as validações estáticas CP-1B a CP-2A: aprovadas;
- build Java 8/Maven 3.8.9 e auditoria major 52: aprovados;
- H2 schema lifecycle e probe MyBatis: aprovados;
- Java 8/WildFly 9/H2: 14/14, `portable-ci`;
- Java 8/WildFly 9/Oracle: 14/14, `oracle-qualified`;
- schema Oracle descartável, datasource JNDI, pool e limpeza: aprovados;
- H2 e Oracle produziram o mesmo WAR e relatórios sanitizados ligados a
  `c76f42f`;
- o CI hospedado aprovou `repository-baseline` e `portable-ci` no workflow
  `30465639289` sobre a conclusão documental ampliada.

## Próximas ações

1. Integrar o PR 15 por squash
   `checkpoint(CP-2A): run legacy application on Java 8`.
2. Iniciar CP-2B tentando o mesmo WAR no Java 8/WildFly 26 antes de corrigir.

## Comandos de retomada

```bash
git status --short --branch
openspec status --change create-java-web-migration-lab --json
openspec instructions apply --change create-java-web-migration-lab --json
./scripts/doctor.sh CP-2A --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
./scripts/validate-cp-2a.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2a-ci-h2.json \
  --contract-result app/target/contract-results/cp-2a-oracle.json
```

As cópias sanitizadas aprovadas estão em
`migration/evidence/CP-2A/`. O `.env`, URLs internas e credenciais continuam
fora do controle de versão.
