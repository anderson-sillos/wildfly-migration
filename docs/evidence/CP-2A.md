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

O resultado depois da correção será preenchido antes do fechamento do PR com:

- `doctor` nos perfis H2 e Oracle;
- WAR compilado no Java 8, bytecode major `52`;
- 20 JARs idênticos ao inventário legado e nenhuma API/driver empacotado;
- 14 contratos `portable-ci` e 14 contratos `oracle-qualified`;
- inicialização sem enviar `MaxPermSize` ao Java 8;
- CI hospedado e rollback documentados.

## Rollback

Use a tag `migration/01-legacy-baseline` e
[`legacy-baseline-reproduction.md`](../legacy-baseline-reproduction.md). O
rollback do código será um novo commit revertendo o squash do CP-2A; nenhum
dado fora do schema descartável do laboratório será removido.
