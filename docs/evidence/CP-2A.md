# Evidência CP-2A — Java 8 no WildFly 9

## Escopo

- entrada: tag `migration/01-legacy-baseline`, commit
  `a7c7b5b92338fc9397967f1916ee525f2dc7c5df`;
- destino: Eclipse Temurin OpenJDK 8u492-b09, Maven 3.8.9 e WildFly
  9.0.2.Final;
- dependências, perfis de banco, JNDI e namespace `javax.*`: inalterados.

## Tentativa antes da correção

O WAR congelado do baseline, SHA-256
`9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`
e bytecode major `51`, iniciou no Java 8/WildFly 9 e aprovou os 14 contratos
H2. A única diferença de inicialização foi o aviso sobre `MaxPermSize`.

A recompilação do worktree destacado com Java 8 terminou com código `1` e a
assinatura esperada:

```text
Detected JDK Version: 1.8.0-492 is not in the allowed range [1.7,1.8).
```

Os registros estruturados são
[`before-runtime.properties`](../../migration/evidence/CP-2A/before-runtime.properties)
e
[`before-build.properties`](../../migration/evidence/CP-2A/before-build.properties).

## Correção e verificações

O código testado foi fixado no commit
`c76f42f4035ac08b13fca478f1d8e375190761b9`. Os dois perfis produziram o mesmo
WAR:

- SHA-256:
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- bytecode Java 8 major `52`;
- 20 JARs em `WEB-INF/lib`;
- árvore Maven com as mesmas 24 dependências e SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`
  do baseline;
- nenhuma API Servlet/JSP/JSTL, H2 ou `ojdbc7` empacotado.

O `doctor` aprovou 107 verificações no perfil H2 e 106 no Oracle, sem falha ou
aviso. O WildFly iniciou sem enviar `MaxPermSize` ao Java 8.

Resultados funcionais sanitizados:

| Trilha | Perfil | Contratos | Resultado |
| --- | --- | ---: | --- |
| `portable-ci` | H2 1.4.200 | 14/14 | aprovado |
| `oracle-qualified` | Oracle 19c RU 19.3 / `ojdbc7` | 14/14 | aprovado |

Os relatórios legíveis por máquina estão em
[`contract-ci-h2.json`](../../migration/evidence/CP-2A/contract-ci-h2.json),
[`contract-oracle.json`](../../migration/evidence/CP-2A/contract-oracle.json)
e
[`after.properties`](../../migration/evidence/CP-2A/after.properties).

O CI hospedado repetirá somente a trilha `portable-ci` sobre o commit do PR. O
resultado Oracle acima foi produzido no host autorizado da rede interna.

## Rollback

Use a tag `migration/01-legacy-baseline` e
[`legacy-baseline-reproduction.md`](../legacy-baseline-reproduction.md). O
rollback do código será um novo commit revertendo o squash do CP-2A; nenhum
dado fora do schema descartável do laboratório será removido.
