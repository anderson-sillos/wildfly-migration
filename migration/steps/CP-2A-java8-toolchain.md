# INC-005 — Build legado bloqueia a JVM Java 8

## Identificação

- checkpoint: `CP-2A`;
- estado verde de origem: `migration/01-legacy-baseline`;
- runtime de destino: Eclipse Temurin 8u492-b09 com Maven 3.8.9;
- etapa: `compilation`;
- categoria: política de toolchain;
- reprodução: `natural`;
- perfis afetados: `portable-ci` e `oracle-qualified`.

## Tentativa antes da correção

O worktree destacado da tag foi compilado diretamente com Temurin 8 e Maven
3.8.9, sem editar o POM:

```bash
JAVA_HOME="$JAVA8_HOME" PATH="$JAVA8_HOME/bin:$PATH" \
  "$MAVEN_HOME/bin/mvn" -f app/pom.xml -Pci-h2 clean package
```

O Maven encerrou com código `1` antes de executar o compilador.

## Assinatura sanitizada

```text
Detected JDK Version: 1.8.0-492 is not in the allowed range [1.7,1.8).
```

## Causa-raiz

O perfil `ci-h2` do baseline restringia o Maven Enforcer à família Java 7.
Essa proteção era correta na fase 1, mas impede intencionalmente que a mesma
fonte seja recompilada no runtime do CP-2A.

## Menor correção

Alterar `source`, `target` e a faixa do Enforcer para Java 8, mantendo Maven
3.8.9, todas as versões de dependências, os escopos e o namespace `javax`.

## Evidências antes e depois

- antes:
  [`before-build.properties`](../evidence/CP-2A/before-build.properties);
- depois: relatório de contratos do PR e manifesto do WAR do CP-2A;
- baseline funcional:
  `migration/baselines/01-legacy/contract-scenarios.tsv`.

## Aplicação equivalente no sistema real

Localize `maven-compiler-plugin`, Enforcer, perfis Maven e propriedades
`maven.compiler.*`. Troque primeiro somente a JVM e essas políticas, sem
aproveitar o checkpoint para atualizar servidor ou bibliotecas.

## Teste de regressão

```bash
./scripts/doctor.sh CP-2A --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
```

O WAR corrigido deve conter bytecode major `52`.

## Rollback

Materialize `migration/01-legacy-baseline` em outro worktree ou reverta o
commit do CP-2A por um novo pull request. Não altere dados Oracle fora do
schema descartável do laboratório.
