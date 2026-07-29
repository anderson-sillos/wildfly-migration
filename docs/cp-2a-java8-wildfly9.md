# CP-2A — Java 8 no WildFly 9

Este checkpoint troca somente a JVM da aplicação. WildFly 9.0.2.Final, Maven
3.8.9, H2 1.4.200, `ojdbc7`, as dependências legadas e os pacotes `javax.*`
permanecem inalterados.

## Entrada e tentativa sem correção

A entrada imutável é a tag `migration/01-legacy-baseline`. Materialize-a sem
criar outra árvore permanente:

```bash
git worktree add --detach ../wildfly-migration-baseline \
  migration/01-legacy-baseline
```

O primeiro experimento executou o WAR congelado, ainda com bytecode Java 7
major `51`, no Java 8/WildFly 9. Os 14 contratos passaram. A recompilação da
mesma fonte falhou antes do compilador porque o Enforcer aceitava somente
`[1.7,1.8)`. As evidências legíveis por máquina estão em
[`migration/evidence/CP-2A/`](../migration/evidence/CP-2A/).

## JDK 8 fixado

O CP-2A usa Eclipse Temurin OpenJDK `8u492-b09`, Linux x64, HotSpot:

- página do release:
  <https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u492-b09>;
- arquivo baixado:
  <https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz>;
- licença: `GPL-2.0-only WITH Classpath-exception-2.0`;
- SHA-256:
  `da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e`.

Baixe o arquivo para `/opt/migration-lab/archives`, valide o digest e extraia
fora do checkout:

```bash
sha256sum /opt/migration-lab/archives/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz
tar -xzf \
  /opt/migration-lab/archives/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz \
  -C /opt/migration-lab/tools
```

O endereço de origem, licença, versão e digest também estão no
[manifesto do runtime](../runtime/phase2/java8-wildfly9/runtime-manifest.tsv).

## Configuração local

Copie os valores de exemplo para o `.env` ignorado:

```dotenv
MIGRATION_CHECKPOINT=CP-2A
JAVA8_HOME=/opt/migration-lab/tools/jdk8u492-b09
JAVA8_ARCHIVE=/opt/migration-lab/archives/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz
JAVA8_ARCHIVE_SHA256=da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e
```

Conserve as configurações externas de Maven 3.8.9, WildFly 9, H2 e Oracle já
usadas no baseline. O perfil continua sendo informado pela linha de comando.

## Validação H2 portátil

```bash
./scripts/doctor.sh CP-2A --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --java 8 \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2a-ci-h2.json
./scripts/validate-cp-2a.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2a-ci-h2.json
```

Essa trilha é classificada somente como `portable-ci`.

## Qualificação Oracle

Execute no host autorizado da rede interna:

```bash
./scripts/doctor.sh CP-2A --profile oracle --env .env
./scripts/oracle-lab-schema.sh verify \
  --java-home "$JAVA8_HOME" --env .env
./scripts/build-cp-2a.sh --profile oracle --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --java 8 \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2a-oracle.json
./scripts/validate-cp-2a.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/cp-2a-oracle.json
```

O JSON é sanitizado e não registra URL, host, usuário ou senha. H2 não
substitui essa qualificação.

## Correções isoladas

- POM e bytecode passam de Java 7 para Java 8;
- Maven permanece em 3.8.9;
- as dependências e a lista de 20 JARs do WAR permanecem idênticas;
- o runtime remove `-XX:MaxPermSize` somente da cópia temporária usada com
  Java 8;
- WildFly continua em 9.0.2.Final e o contrato JNDI continua
  `java:/jdbc/MigrationDS`.

## Rollback

Pare o runtime temporário com `Ctrl+C` no modo manual. Para voltar ao último
estado verde, materialize `migration/01-legacy-baseline` e use seu runbook.
No branch principal, reverta o squash do CP-2A por um novo pull request; não
reescreva o histórico nem execute `rollback.sql` no schema compartilhado.
