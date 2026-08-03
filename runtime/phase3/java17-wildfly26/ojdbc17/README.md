# Driver Oracle externo do gate Java 17

O `ojdbc17.jar` é um componente do runtime do WildFly, não da aplicação. Ele
fica fora do WAR, do Git e dos caches públicos e é copiado somente para o
módulo isolado do servidor:

- módulo: `com.oracle.ojdbc17`;
- arquivo: `ojdbc17.jar`;
- classe JDBC: `oracle.jdbc.OracleDriver`;
- versão fixada: `23.26.2.0.0`;
- diretório no WildFly 26: `modules/com/oracle/ojdbc17/main/`.

O artefato é obtido do Maven Central, sob Oracle Free Use Terms and Conditions
(FUTC), e o SHA-256 aprovado é
`96010f27fce64c285f9d1aab8f96357b8e00c49c9ad041ecf140c9d7d27eb3fb`.
O Oracle publica a mesma linha como driver certificado para JDK 17 e compatível
com Oracle Database 19c.

## Provisionamento

1. Baixe o JAR no endereço registrado em `runtime-manifest.tsv` e valide o
   SHA-256.
2. Configure `OJDBC17_JAR` e `OJDBC17_SHA256` no `.env` ignorado.
3. Execute `doctor.sh CP-3C --profile oracle --env .env`.
4. O smoke copia o JAR para o diretório exato do módulo e aplica
   `register-driver.cli` por meio de `profiles/oracle.cli`.

O perfil `ci-h2` não lê essas variáveis e continua usando apenas H2 2.4.240 em
memória. O rollback remove o datasource, o registro e somente
`com/oracle/ojdbc17/main`; não remova a árvore geral de módulos do WildFly.
