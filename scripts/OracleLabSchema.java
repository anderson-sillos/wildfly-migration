import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.HashSet;
import java.util.Set;

public final class OracleLabSchema {
    private static final Set<String> REQUIRED_PRIVILEGES =
            new HashSet<String>();
    private static final Set<String> ALLOWED_TABLES =
            new HashSet<String>();
    private static final Set<String> ALLOWED_SEQUENCES =
            new HashSet<String>();

    static {
        REQUIRED_PRIVILEGES.add("CREATE SESSION");
        REQUIRED_PRIVILEGES.add("CREATE TABLE");
        REQUIRED_PRIVILEGES.add("CREATE SEQUENCE");
        ALLOWED_TABLES.add("LAB_PEDIDO");
        ALLOWED_TABLES.add("LAB_ANEXO");
        ALLOWED_SEQUENCES.add("LAB_PEDIDO_SEQ");
        ALLOWED_SEQUENCES.add("LAB_ANEXO_SEQ");
    }

    private OracleLabSchema() {
    }

    public static void main(String[] args) {
        if (args.length != 2) {
            System.err.println(
                    "FALHA: uso interno OracleLabSchema "
                    + "<inspect|apply|verify|cleanup-smokes> "
                    + "<raiz>");
            System.exit(2);
        }

        String url = System.getenv("ORACLE_DB_URL");
        String user = System.getenv("ORACLE_DB_USER");
        String password = System.getenv("ORACLE_DB_PASSWORD");
        if (empty(url) || empty(user) || empty(password)) {
            System.err.println(
                    "FALHA: configuração Oracle não chegou ao processo");
            System.exit(1);
        }

        Connection connection = null;
        try {
            Class.forName("oracle.jdbc.OracleDriver");
            connection = DriverManager.getConnection(url, user, password);
            connection.setAutoCommit(false);
            inspect(connection);

            if ("apply".equals(args[0])) {
                File root = new File(args[1]);
                executeScript(connection, new File(root,
                        "app/src/main/resources/db/oracle/001_schema.sql"));
                executeScript(connection, new File(root,
                        "app/src/main/resources/db/oracle/002_seed.sql"));
                connection.commit();
                verify(connection);
                System.out.println(
                        "OK: schema e seed Oracle LAB_* aplicados e verificados");
            } else if ("verify".equals(args[0])) {
                verify(connection);
                System.out.println(
                        "OK: schema e seed Oracle LAB_* verificados");
            } else if ("inspect".equals(args[0])) {
                System.out.println(
                        "OK: identidade, quota, privilégios e escopo Oracle "
                        + "aprovados");
            } else if ("cleanup-smokes".equals(args[0])) {
                cleanupSmokes(connection);
                connection.commit();
                System.out.println(
                        "OK: dados transitórios LAB-SMOKE-* removidos");
            } else {
                throw new IllegalArgumentException("ação interna inválida");
            }
        } catch (SQLException exception) {
            rollback(connection);
            System.err.println(
                    "FALHA: operação Oracle recusada (SQLState="
                    + safe(exception.getSQLState()) + ", código="
                    + exception.getErrorCode() + ")");
            System.exit(1);
        } catch (IllegalArgumentException exception) {
            rollback(connection);
            System.err.println(
                    "FALHA: validação Oracle recusou o alvo: "
                    + exception.getMessage());
            System.exit(1);
        } catch (Exception exception) {
            rollback(connection);
            System.err.println(
                    "FALHA: operação Oracle recusada por validação local");
            System.exit(1);
        } finally {
            close(connection);
        }
    }

    private static void inspect(Connection connection) throws SQLException {
        Statement statement = connection.createStatement();
        try {
            ResultSet identity = statement.executeQuery(
                    "SELECT USER, "
                    + "SYS_CONTEXT('USERENV','CURRENT_SCHEMA'), "
                    + "SYS_CONTEXT('USERENV','CON_NAME') FROM DUAL");
            require(identity.next(), "identidade Oracle ausente");
            String sessionUser = identity.getString(1);
            String currentSchema = identity.getString(2);
            String container = identity.getString(3);
            identity.close();
            require(sessionUser != null
                    && sessionUser.equalsIgnoreCase(currentSchema),
                    "schema atual diverge do usuário");
            require(container != null
                    && !"CDB$ROOT".equalsIgnoreCase(container),
                    "container raiz não pode ser usado");

            ResultSet roles = statement.executeQuery(
                    "SELECT GRANTED_ROLE FROM USER_ROLE_PRIVS");
            require(!roles.next(),
                    "schema não deve receber papéis");
            roles.close();

            Set<String> privileges = new HashSet<String>();
            ResultSet privilegeRows = statement.executeQuery(
                    "SELECT PRIVILEGE FROM SESSION_PRIVS");
            while (privilegeRows.next()) {
                privileges.add(privilegeRows.getString(1));
            }
            privilegeRows.close();
            require(privileges.equals(REQUIRED_PRIVILEGES),
                    "privilégios devem ser exatamente os mínimos");

            ResultSet quotas = statement.executeQuery(
                    "SELECT BYTES, MAX_BYTES FROM USER_TS_QUOTAS");
            boolean limitedQuota = false;
            while (quotas.next()) {
                long maximum = quotas.getLong(2);
                if (!quotas.wasNull() && maximum > 0L) {
                    limitedQuota = true;
                }
                require(maximum != -1L, "quota ilimitada não é permitida");
            }
            quotas.close();
            require(limitedQuota, "quota limitada ausente");

            validateOwnedObjects(statement);
        } finally {
            statement.close();
        }
    }

    private static void validateOwnedObjects(Statement statement)
            throws SQLException {
        validateNames(statement,
                "SELECT TABLE_NAME FROM USER_TABLES",
                ALLOWED_TABLES, "tabela externa ao laboratório");
        validateNames(statement,
                "SELECT SEQUENCE_NAME FROM USER_SEQUENCES",
                ALLOWED_SEQUENCES, "sequence externa ao laboratório");
        require(count(statement, "SELECT COUNT(*) FROM USER_VIEWS") == 0L,
                "view externa ao laboratório");
        require(count(statement,
                "SELECT COUNT(*) FROM USER_PROCEDURES") == 0L,
                "procedure externa ao laboratório");
        require(count(statement,
                "SELECT COUNT(*) FROM USER_SYNONYMS") == 0L,
                "synonym externo ao laboratório");
        require(count(statement,
                "SELECT COUNT(*) FROM USER_INDEXES "
                + "WHERE TABLE_NAME NOT IN ('LAB_PEDIDO','LAB_ANEXO')") == 0L,
                "índice externo ao laboratório");
    }

    private static void validateNames(
            Statement statement,
            String sql,
            Set<String> allowed,
            String message) throws SQLException {
        ResultSet rows = statement.executeQuery(sql);
        try {
            while (rows.next()) {
                require(allowed.contains(rows.getString(1)), message);
            }
        } finally {
            rows.close();
        }
    }

    private static void verify(Connection connection) throws SQLException {
        String databaseVersion =
                connection.getMetaData().getDatabaseProductVersion();
        require(databaseVersion != null
                && databaseVersion.indexOf("19.3.0.0.0") >= 0,
                "Oracle Database RU diverge de 19.3.0.0.0");

        Statement statement = connection.createStatement();
        try {
            require(count(statement,
                    "SELECT COUNT(*) FROM USER_TABLES "
                    + "WHERE TABLE_NAME IN ('LAB_PEDIDO','LAB_ANEXO')") == 2L,
                    "tabelas LAB_* ausentes");
            require(count(statement,
                    "SELECT COUNT(*) FROM USER_SEQUENCES "
                    + "WHERE SEQUENCE_NAME IN "
                    + "('LAB_PEDIDO_SEQ','LAB_ANEXO_SEQ')") == 2L,
                    "sequences LAB_* ausentes");
            require(count(statement,
                    "SELECT COUNT(*) FROM LAB_PEDIDO "
                    + "WHERE NUMERO = 'LAB-0001'") == 1L,
                    "seed Oracle ausente ou duplicado");
            validateOwnedObjects(statement);
        } finally {
            statement.close();
        }

        PreparedStatement seed = connection.prepareStatement(
                "SELECT CLIENTE_NOME, DESCRICAO, VALOR_TOTAL, STATUS "
                + "FROM LAB_PEDIDO WHERE NUMERO = ?");
        try {
            seed.setString(1, "LAB-0001");
            ResultSet row = seed.executeQuery();
            try {
                require(row.next(), "seed Oracle ausente");
                require("Cliente de referência".equals(row.getString(1)),
                        "cliente do seed Oracle divergente");
                require("Pedido mínimo para validar o baseline".equals(
                        row.getString(2)),
                        "descrição do seed Oracle divergente");
                BigDecimal value = row.getBigDecimal(3);
                require(value != null
                        && value.compareTo(new BigDecimal("125.50")) == 0,
                        "valor do seed Oracle divergente");
                require("NOVO".equals(row.getString(4)),
                        "status do seed Oracle divergente");
                require(!row.next(), "seed Oracle duplicado");
            } finally {
                row.close();
            }
        } finally {
            seed.close();
        }
    }

    private static void cleanupSmokes(Connection connection)
            throws SQLException {
        PreparedStatement statement = connection.prepareStatement(
                "DELETE FROM LAB_ANEXO WHERE PEDIDO_ID IN "
                + "(SELECT ID FROM LAB_PEDIDO WHERE NUMERO LIKE ?)");
        try {
            statement.setString(1, "LAB-SMOKE-%");
            statement.executeUpdate();
        } finally {
            statement.close();
        }

        statement = connection.prepareStatement(
                "DELETE FROM LAB_PEDIDO WHERE NUMERO LIKE ?");
        try {
            statement.setString(1, "LAB-SMOKE-%");
            statement.executeUpdate();
        } finally {
            statement.close();
        }
    }

    private static long count(Statement statement, String sql)
            throws SQLException {
        ResultSet result = statement.executeQuery(sql);
        try {
            require(result.next(), "consulta de contagem sem resultado");
            return result.getLong(1);
        } finally {
            result.close();
        }
    }

    private static void executeScript(Connection connection, File file)
            throws Exception {
        require(file.isFile(), "script Oracle ausente");
        Reader input = new InputStreamReader(
                new FileInputStream(file), "UTF-8");
        BufferedReader reader = new BufferedReader(input);
        StringBuilder command = new StringBuilder();
        boolean plsql = false;
        try {
            String line;
            while ((line = reader.readLine()) != null) {
                String trimmed = line.trim();
                if (trimmed.length() == 0 || trimmed.startsWith("--")) {
                    continue;
                }
                if (command.length() == 0) {
                    plsql = "DECLARE".equalsIgnoreCase(trimmed)
                            || "BEGIN".equalsIgnoreCase(trimmed);
                }
                if (plsql && "/".equals(trimmed)) {
                    execute(connection, command.toString());
                    command.setLength(0);
                    plsql = false;
                    continue;
                }
                command.append(line).append('\n');
                if (!plsql && trimmed.endsWith(";")) {
                    command.setLength(command.length() - 2);
                    execute(connection, command.toString());
                    command.setLength(0);
                }
            }
            require(command.toString().trim().length() == 0,
                    "comando Oracle incompleto");
        } finally {
            reader.close();
        }
    }

    private static void execute(Connection connection, String sql)
            throws SQLException {
        Statement statement = connection.createStatement();
        try {
            statement.execute(sql);
        } finally {
            statement.close();
        }
    }

    private static void rollback(Connection connection) {
        if (connection != null) {
            try {
                connection.rollback();
            } catch (SQLException ignored) {
                // A mensagem original permanece sanitizada.
            }
        }
    }

    private static void close(Connection connection) {
        if (connection != null) {
            try {
                connection.close();
            } catch (SQLException ignored) {
                // O processo termina sem reutilizar a conexão.
            }
        }
    }

    private static String safe(String value) {
        if (value == null || !value.matches("[A-Za-z0-9]{1,16}")) {
            return "indisponivel";
        }
        return value;
    }

    private static boolean empty(String value) {
        return value == null || value.trim().length() == 0;
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
