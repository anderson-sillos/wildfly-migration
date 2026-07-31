# INC-011 — Build da fase 2 bloqueia a JVM Java 17

## Identificação

- checkpoint: `CP-3A`;
- estado verde de origem: `migration/02-java8-wildfly26`;
- runtime de destino: Eclipse Temurin 17.0.20+8 com Maven 3.9.16;
- etapa: `compilation`;
- categoria: política de toolchain;
- reprodução: `natural`;
- perfis afetados: `portable-ci` e `oracle-qualified`.

## Tentativa antes da correção

O POM e a fonte da fase 2 foram submetidos diretamente ao Maven 3.9.16
executando no Temurin 17, sem atualização de dependência:

```bash
JAVA_HOME="$JAVA17_HOME" PATH="$JAVA17_HOME/bin:$PATH" \
  "$MAVEN_HOME/bin/mvn" -B -ntp \
    -f app/pom.xml -Pci-h2 clean verify
```

O Maven encerrou com código `1` antes de executar o compilador.

## Assinatura sanitizada

```text
Detected JDK Version: 17.0.20 is not in the allowed range [1.8,1.9).
```

## Causa-raiz

O Maven Enforcer preserva corretamente a família Java 8 como padrão da fase
2. A política impede intencionalmente uma recompilação silenciosa por uma JVM
mais recente.

## Menor correção

O wrapper `scripts/build-cp-3a.sh` seleciona o JDK 17 e passa ao Maven somente
as propriedades `phase2.java.version.range=[17,18)`,
`maven.compiler.source=17` e `maven.compiler.target=17`. Fonte, POM,
dependências, escopos, plugins e namespace `javax` permanecem inalterados.

Essa sobreposição é deliberadamente transitória. A atividade 3.4 promoverá
Java 17 para o padrão do projeto quando CI, `doctor`, runtime H2 e documentação
forem atualizados juntos. Isso mantém o build padrão Java 8 capaz de reproduzir
byte a byte o manifesto da fase 2 durante as atividades 3.1 a 3.3.

## Teste de regressão

```bash
./scripts/build-cp-3a.sh --profile ci-h2 --env .env
```

O WAR deve conter bytecode major `61`, os mesmos 20 JARs e a mesma árvore
Maven da fase 2.

## Aplicação equivalente no sistema real

Execute primeiro a compilação no JDK novo sem atualizar bibliotecas. Ajuste
apenas a faixa do Enforcer e o nível de bytecode; depois de comprovado o
resultado, transforme essa seleção no padrão do projeto junto com o CI.

## Rollback

Use `scripts/build-cp-2c.sh` para selecionar Java 8 novamente. O POM não foi
alterado por esta correção e o build padrão continua produzindo o WAR
congelado da fase 2.
