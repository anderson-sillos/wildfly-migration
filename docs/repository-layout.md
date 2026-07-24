# Estrutura do repositório

O laboratório usa uma única aplicação que evolui sobre a branch principal.

| Caminho | Conteúdo |
| --- | --- |
| `app/` | única árvore Maven da aplicação |
| `contract-tests/` | contratos externos, independentes das classes do WAR |
| `runtime/` | configuração e automação dos runtimes por fase e gate |
| `migration/steps/` | roteiro e evidências das incompatibilidades |
| `docs/` | documentação transversal e evidências de checkpoints |
| `openspec/` | proposta, decisões, requisitos e tarefas executáveis |
| `scripts/` | diagnóstico e automações portáteis do repositório |

## Invariantes

- Não criar árvores como `legacy-app`, `modern-app` ou equivalentes.
- Alterar `app/` progressivamente a partir do último checkpoint verde.
- Usar Git worktrees quando dois estados precisarem ser executados lado a lado.
- Preservar somente os finais das três fases pelas tags
  `migration/01-legacy-baseline`, `migration/02-java8-wildfly26` e
  `migration/03-final`.
- Não versionar runtimes, JARs manuais, credenciais ou artefatos de build.

O scaffold do CP-1B contém apenas diretórios e fronteiras de responsabilidade.
O WAR e suas dependências começam no CP-1C.
