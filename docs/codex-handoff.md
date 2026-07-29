# Codex handoff

Atualizado em 2026-07-29 durante o checkpoint `CP-2B`.

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
- Branch: `checkpoint/cp-2b-wildfly26`.
- Último squash no `main`: `bce4fb9`, fechamento do `CP-2A` pelo PR 15.
- Tag pública da fase 1:
  `migration/01-legacy-baseline`, apontando para `a7c7b5b`.
- Tarefas OpenSpec 2.1 a 2.9 concluídas.
- Progresso preparado: 44 de 110 tarefas.

## CP-2A encerrado

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
- o CI hospedado aprovou os checks finais no workflow `30465991815`;
- o PR 15 foi integrado pelo squash
  `bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`.

## CP-2B iniciado

- WildFly comunitário 26.1.3.Final baixado do release oficial:
  `wildfly-26.1.3.Final.tar.gz`;
- SHA-1 publicado:
  `b9f52ba41df890e09bb141d72947d2510caf758c`;
- SHA-256 fixado:
  `aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59`;
- instalação externa:
  `/opt/migration-lab/tools/wildfly-26.1.3.Final`;
- o `.env` local ignorado foi selecionado para `CP-2B` e recebeu os três
  valores `WILDFLY26_*`;
- `doctor CP-2B/ci-h2`: 108 OK, sem falha ou aviso;
- o WAR aprovado no CP-2A manteve SHA-256
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- a tentativa sem correção iniciou o WildFly em loopback, mas deixou o
  deployment `FAILED` e o health em `404`;
- causa natural catalogada como `INC-007`: ausência de
  `java:/jdbc/MigrationDS` na configuração original do WildFly 26;
- aviso preliminar `WFLYLOG0100`: suporte a `log4j.properties` no deployment
  está depreciado, catalogado como `INC-008` e adiado para `CP-3B`;
- `INC-009`: listener HTTPS e recursos de keystore removidos somente da cópia
  temporária;
- `INC-010`: CLI do WildFly 26 não aceita `pool-name`; perfis próprios
  preservam o restante do contrato;
- H2 e Oracle aprovaram 14/14 contratos, pool, health e classloader no runtime
  `java8-wildfly26.1.3`, vinculados ao commit
  `5d1f6be20168909e8777a5f8a479e7d6b6d4a81a`;
- `INC-008` permanece não bloqueante; foi registrada a alternativa de retirar
  a configuração do WAR sem trocar a biblioteca, preferindo o subsistema de
  logging a uma propriedade global de arquivo externo.

## Próximas ações

1. Validar as evidências congeladas e criar o commit documental.
2. Abrir o PR do CP-2B e confirmar o CI portátil.
3. Encerrar 2.10 e integrar por squash depois das validações e da conclusão
   explicativa.

## Comandos de retomada

```bash
git status --short --branch
openspec status --change create-java-web-migration-lab --json
openspec instructions apply --change create-java-web-migration-lab --json
./scripts/doctor.sh CP-2B --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
./scripts/validate-cp-2b.sh --war app/target/wildfly-migration.war
```

A primeira evidência sanitizada do CP-2B está em
`migration/evidence/CP-2B/before-deployment.properties`. O `.env`, logs
temporários, URLs internas e credenciais continuam fora do controle de versão.
