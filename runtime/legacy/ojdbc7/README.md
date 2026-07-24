# Driver Oracle externo

O `ojdbc7.jar` pertence ao runtime do WildFly e não ao WAR. Ele nunca deve ser
copiado para `app/`, `WEB-INF/lib`, o repositório Git ou artefatos da CI.

## Contrato deste checkpoint

- módulo do WildFly: `com.oracle.ojdbc7`;
- nome esperado no módulo: `ojdbc7.jar`;
- driver JDBC: `oracle.jdbc.OracleDriver`;
- datasource da aplicação: `java:/jdbc/MigrationDS`;
- localização do módulo no WildFly 9:
  `modules/system/layers/base/com/oracle/ojdbc7/main/`.

O arquivo licenciado deve ser baixado pelo responsável no canal oficial da
Oracle, mantido fora do checkout e identificado por SHA-256 no `.env`. Não
forneça login, cookie de sessão ou senha ao projeto.

O CP-1C valida o contrato e comprova que o driver não foi empacotado. A cópia
controlada para o módulo, o registro do driver, a criação do datasource e a
conexão real com Oracle 19c pertencem ao CP-1D.

## Provisionamento futuro

1. Valide o checksum do arquivo externo.
2. Crie o diretório exato do módulo no WildFly isolado.
3. Copie o arquivo como `ojdbc7.jar`.
4. Copie `module.xml.template` como `module.xml`.
5. Inicie o WildFly com as variáveis Oracle fornecidas por mecanismo seguro.
6. Execute `register-driver.cli` com `jboss-cli.sh`.

O rollback remove o datasource e o registro do driver antes de apagar somente
o diretório exato `com/oracle/ojdbc7/main`. Não remova a árvore ampla de
módulos do WildFly.
