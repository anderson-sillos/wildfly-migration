# CP-3C — Oracle JDBC mantido no gate Java 17

## Decisão

O módulo externo `com.oracle.ojdbc7` deixa de ser usado no runtime Java 17 do
laboratório. O gate CP-3C passa a provisionar
`com.oracle.database.jdbc:ojdbc17:23.26.2.0.0`, renomeado para `ojdbc17.jar`,
no módulo WildFly `com.oracle.ojdbc17`. A aplicação continua obtendo o pool
por `java:/jdbc/MigrationDS`; nenhuma classe de negócio conhece o fornecedor.

O artefato é compatível com JDK 17 e Oracle Database 19c, é distribuído sob
Oracle Free Use Terms and Conditions (FUTC) e está fixado no manifesto e no
checksum do ambiente externo. A fonte e o checksum publicado são:

```text
https://repo.maven.apache.org/maven2/com/oracle/database/jdbc/ojdbc17/23.26.2.0.0/ojdbc17-23.26.2.0.0.jar
SHA-256: 96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb
```

O driver não entra em `app/pom.xml`, `WEB-INF/lib` ou no artefato WAR. Ele fica
fora do cache portátil do GitHub Actions e é fornecido externamente por
`OJDBC17_JAR` somente no perfil Oracle. O job hospedado continua no perfil
`ci-h2` e não abre conexão Oracle nem publica credenciais.

## Perfis

| Perfil | Driver | Resultado |
| --- | --- | --- |
| `ci-h2` | H2 2.4.240, módulo `com.h2database.h2.cp3a` | `portable-ci`, sem variáveis Oracle |
| `oracle` | ojdbc17 23.26.2.0.0, módulo `com.oracle.ojdbc17` | `oracle-qualified`, somente na rede interna autorizada |

Ambos os perfis publicam `java:/jdbc/MigrationDS`. O pool Oracle usa a mesma
URL externa, usuário e senha fornecidos pelo DBA; o H2 permanece em memória,
sem console, listener ou arquivo persistente.

## Validação

Primeiro valide a identidade do componente e a configuração local:

```bash
./scripts/validate-cp-3c-ojdbc17.sh --env .env
```

Depois execute a trilha portátil:

```bash
./scripts/qualify-cp-3c-h2.sh --env .env
```

Em um host autorizado para o Oracle 19c, execute:

```bash
./scripts/qualify-cp-3c-oracle.sh --env .env
```

A qualificação Oracle exige o schema descartável aprovado e valida conexão,
commit, rollback, `TIMESTAMP(6)`, BLOB, mappers e limpeza de dados transitórios.
O relatório sanitizado não contém URL, usuário, senha ou wallet.

## Rollback

O rollback restaura o profile Oracle anterior e o módulo externo `ojdbc7` em um
checkout/tag da fase 2; não se deve misturar os módulos no mesmo servidor. No
runtime Java 17, remova somente o datasource, o registro e
`modules/com/oracle/ojdbc17/main` depois de desligar o servidor isolado.

## Fontes

- [Oracle JDBC downloads e matriz de interoperabilidade](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html);
- [ojdbc17 23.26.2.0.0 no Maven Central](https://repo.maven.apache.org/maven2/com/oracle/database/jdbc/ojdbc17/23.26.2.0.0/);
- [Oracle Free Use Terms and Conditions](https://www.oracle.com/downloads/licenses/oracle-free-license.html).
