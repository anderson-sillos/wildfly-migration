# CP-3A — Runtime Java 17 no WildFly 26

## Escopo das atividades 3.4 e 3.5

O runtime ativo passa a usar:

| Componente | Versão | Papel |
| --- | --- | --- |
| Eclipse Temurin OpenJDK | 17.0.20+8 | JVM e compilador padrão |
| WildFly comunitário | 26.1.3.Final | servidor EE 8 de transição |
| Apache Maven | 3.9.16 | ferramenta de build |
| H2 | 2.4.240 | banco em memória exclusivo de `portable-ci` |
| Oracle Database | 19c | banco canônico externo de `oracle-qualified` |
| Oracle JDBC | `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` | módulo externo do gate Java 17, fora do WAR |

Versão, origem, licença e SHA-256 dos componentes redistribuíveis ficam
no [manifesto do runtime](../runtime/phase3/java17-wildfly26/runtime-manifest.tsv).
Os links não usam `latest`. O H2 2.4.240 é a versão publicada em 22/09/2025 e
seu JAR foi construído para Java 11 (bytecode major 55), portanto executa no
Java 17 fixado.

## O que mudou

- Java 17 e o bytecode major 61 são agora o padrão do POM; o wrapper
  `build-cp-3a.sh` não injeta mais `source`, `target` ou a faixa do Enforcer;
- o H2 2.4.240 possui módulo e perfil próprios sob
  `runtime/phase3/java17-wildfly26`;
- o cache portátil único retém tanto H2 1.4.200 quanto H2 2.4.240: a versão
  histórica atende às tags anteriores, e a versão atual atende ao CP-3A;
- o CI portátil monta Java 17/WildFly 26/H2 2.4.240 e continua compilando as
  sondas Oracle sem driver ou credenciais;
- o perfil Oracle continua isolado e usa `ojdbc17` a partir do CP-3C; a
  atualização é a atividade 3.14.

O H2 permanece fora do WAR e usa somente
`jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1`. O perfil não habilita
console, listener TCP, `AUTO_SERVER` ou persistência em arquivo.

## Preparação local

Baixe o H2 pelo endereço fixo:

```text
https://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/h2-2.4.240.jar
SHA-256: 29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0
```

Atualize somente as entradas locais `MIGRATION_CHECKPOINT`, `H2_JAR` e
`H2_SHA256` no `.env`; mantenha as credenciais Oracle existentes fora do
repositório:

```text
MIGRATION_CHECKPOINT=CP-3A
H2_JAR=/opt/migration-lab/archives/h2-2.4.240.jar
H2_SHA256=29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0
```

Valide o ambiente portátil:

```bash
./scripts/doctor.sh CP-3A --profile ci-h2 --env .env
./scripts/build-cp-3a.sh --profile ci-h2 --env .env
./scripts/validate-cp-1d-h2.sh \
  --java-home /opt/migration-lab/tools/jdk-17.0.20+8 \
  --h2-jar /opt/migration-lab/archives/h2-2.4.240.jar
./scripts/validate-cp-1e-persistence.sh \
  --java-home /opt/migration-lab/tools/jdk-17.0.20+8 \
  --h2-jar /opt/migration-lab/archives/h2-2.4.240.jar \
  --war app/target/wildfly-migration.war
```

## Fechamento reproduzível

Execute primeiro a trilha portátil:

```bash
./scripts/qualify-cp-3a-h2.sh --env .env
```

Ela executa `doctor`, build Java 17, auditoria, ciclo do schema H2, sonda
MyBatis e os 14 contratos externos. O relatório permanece classificado como
`portable-ci`.

Em uma máquina autorizada na rede interna, execute depois:

```bash
./scripts/qualify-cp-3a-oracle.sh --env .env
```

O executor exige o relatório H2 do mesmo diretório, reconstrói o mesmo WAR no
perfil Oracle, executa os 14 contratos, compara o estado persistido e valida
commit/rollback MyBatis, `TIMESTAMP(6)` e BLOB. O `trap` de limpeza remove
somente os registros `LAB-SMOKE-*`, inclusive se uma etapa falhar.

O fechamento aprovado e as limitações estão na
[evidência do CP-3A](evidence/CP-3A.md). A trilha Oracle do CP-3C usa o
`ojdbc17` externo, provisionado fora do WAR.

## Rollback

Para reproduzir a fase 2, use a tag imutável
`migration/02-java8-wildfly26` em outro worktree e seu próprio `.env`. Não
substitua o manifesto ou o módulo histórico no checkout atual. O rollback da
atividade 3.4 consiste em voltar ao commit anterior do PR; nenhuma alteração de
schema Oracle é executada pela promoção do runtime.

## Fontes

- [H2 2.4.240 — release oficial](https://github.com/h2database/h2database/releases/tag/version-2.4.240);
- [H2 2.4.240 — artefato no Maven Central](https://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/);
- [licença do H2](https://h2database.com/html/license.html);
- [Temurin 17.0.20+8](https://github.com/adoptium/temurin17-binaries/releases/tag/jdk-17.0.20%2B8);
- [WildFly 26.1.3.Final](https://github.com/wildfly/wildfly/releases/tag/26.1.3.Final).
