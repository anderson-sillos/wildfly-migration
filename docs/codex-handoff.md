# Codex handoff

Atualizado em 2026-07-28 durante o checkpoint `CP-1F`.

Este documento preserva o contexto operacional necessário para continuar o
laboratório em outra sessão do Codex. Ele não substitui o OpenSpec, o runbook
ou as evidências dos checkpoints e não deve conter credenciais, URLs Oracle,
endereços internos nem conteúdo do `.env`.

## Objetivo e decisões consolidadas

- Repositório: `anderson-sillos/wildfly-migration`, na conta pessoal
  `anderson-sillos`.
- Licença: GNU AGPL 3.0.
- Identidade Git do projeto: `asillos@gmail.com`.
- O laboratório evolui uma única árvore Maven `app/`; não existem projetos
  paralelos chamados `legacy-app` ou `modern-app`.
- Cada checkpoint parcial usa uma branch `checkpoint/*`, um pull request e um
  squash merge identificável. A validação manual deve terminar antes do merge.
- As três fases públicas são:
  1. baseline Java 7u80, Maven 3.8.9 e WildFly 9.0.2;
  2. modernização de baixo impacto para Java 8 e WildFly 26.1.3, ainda em
     `javax.*`;
  3. destino final open source em OpenJDK 25, WildFly 41 comunitário e Jakarta
     EE 11, com gates internos em Java 17 e Java 21.
- H2 em memória fornece somente evidência `portable-ci`. Oracle Database 19c
  RU 19.3, acessível pela rede interna, fornece a qualificação oficial
  `oracle-qualified`.
- Ambos os perfis publicam `java:/jdbc/MigrationDS` por pool gerenciado pelo
  WildFly. H2 e drivers Oracle permanecem fora do WAR.
- O arquivo `.env` local está ignorado e configurado; nunca mostrar ou
  versionar seus valores.
- A documentação operacional foi consolidada em
  `docs/legacy-application-runbook.md`. Decisões e evidências permanecem em
  documentos próprios.

## Planejamento e estado atual

- Mudança OpenSpec: `create-java-web-migration-lab`.
- Checklist:
  `openspec/changes/create-java-web-migration-lab/tasks.md`.
- Progresso preparado para integração: 30 de 110 tarefas concluídas.
- Branch atual: `checkpoint/cp-1f-integrations-contracts`.
- Pull request: `#12`, `[CP-1F] Integrações e contratos legados`, ainda em
  draft.
- Revisão funcional final:
  `a90e419f1b1c13df226583bcacfc82056c77c9fd`.
- Último checkpoint integrado no `main`: `CP-1E`, commit abreviado `c85f607`.

As atividades 1.26 a 1.29 estão concluídas. Elas entregam:

- upload com Commons FileUpload 1.2.2;
- importação XML por XMLBeans 2.3.0 e dom4j 1.6.1;
- validação XSD, proteção contra XXE e cenários negativos;
- descoberta ordenada de validadores por Reflections 0.9.10;
- logging legado por Log4j 1.2.14;
- contratos HTTP externos comuns aos perfis H2 e Oracle.

A atividade 1.30 está marcada no conteúdo preparado para integração. O
encerramento se torna efetivo quando o PR produzir o squash
`checkpoint(CP-1F): add legacy integrations and contracts` no `main`.

## Validações já aprovadas

- O usuário confirmou em 2026-07-28 que a validação manual final está OK.
- O gate manual comprovou a importação válida, a rejeição por
  `StatusInicialValidator`, a ordem dos três validadores, o log
  `reason=domain_validator` e a ausência do pedido rejeitado.
- O PR publicou checks verdes `repository-baseline` e `portable-ci` no run
  `30409005015`, ainda antes das correções locais finais.
- Uma execução local anterior aprovou os mesmos 14 cenários em H2 e Oracle
  sobre o commit `e006eacb8a96df7dc00437ba8c0f1dc808b27b2c`.
- Sobre a árvore local com as correções finais de logging:
  - `doctor CP-1F/ci-h2`: 87 verificações OK;
  - `doctor CP-1F/oracle`: 86 verificações OK;
  - build Java 7/Maven 3.8.9: aprovado;
  - WAR: 20 bibliotecas e SHA-256
    `9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`;
  - validações estáticas de documentação, upload, XML, Reflections/Log4j e
    contratos: aprovadas;
  - persistência MyBatis e ciclo do schema H2: aprovados;
  - contratos e smoke WildFly 9/H2: 14 cenários aprovados;
  - contratos e smoke WildFly 9/Oracle: os mesmos 14 cenários aprovados com
    resultado `oracle-qualified`.

A primeira tentativa do smoke H2 na sessão Codex falhou porque o sandbox
impediu a criação de sockets. A repetição autorizada fora desse isolamento,
restrita a loopback, foi aprovada. Isso é uma limitação do executor, não uma
falha da aplicação.

## Alterações locais que pertencem ao CP-1F

- tasks do VS Code para iniciar a aplicação em H2 ou Oracle e acompanhar o log;
- `scripts/follow-wildfly9-log.sh` e marcador seguro da sessão manual;
- documentação e validação estática dessas tasks;
- preservação do `Throwable` em logs de falhas internas de pedidos, upload e
  XML;
- propagação da causa original quando o listener falha na inicialização;
- contrato estático que exige a exceção completa nos pontos de logging.

O arquivo `.vscode/settings.json` é deliberadamente versionado porque contém
os runtimes Java e o comportamento de importação usados pelo workspace. A
configuração `java.compile.nullAnalysis.mode=automatic` também será
compartilhada; não adicionar esse arquivo ao `.gitignore`.

## Próximas ações

1. Versionar esta atualização final da evidência, do handoff e do OpenSpec.
2. Enviar o commit, atualizar o corpo do PR e aguardar os checks finais.
3. Retirar o PR do draft e executar o squash planejado.
4. Iniciar o `CP-1G` pela atividade 1.31.

## Comandos de retomada

```bash
git status --short --branch
openspec status --change create-java-web-migration-lab --json
openspec instructions apply --change create-java-web-migration-lab --json
gh pr view 12 --repo anderson-sillos/wildfly-migration
gh pr checks 12 --repo anderson-sillos/wildfly-migration
```

As execuções locais documentadas usam:

```bash
./scripts/doctor.sh CP-1F --profile ci-h2 --env .env
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json
```

Para Oracle, troque o perfil por `oracle` somente em uma máquina autorizada na
rede interna. Os relatórios em `app/target/contract-results/` são derivados
locais; a evidência sanitizada relevante deve ser transcrita para
`docs/evidence/CP-1F.md`.
