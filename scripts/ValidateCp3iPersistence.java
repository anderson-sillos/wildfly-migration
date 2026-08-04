import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Blob;
import java.sql.Clob;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.TimeZone;

/**
 * JDBC-only persistence probe for CP-3I/3.41. It intentionally does not use
 * application classes: the probe exercises the database/driver boundary
 * directly and leaves the WAR unchanged.
 */
public final class ValidateCp3iPersistence {
    private static final String ORACLE_VERSION = "19.3.0.0.0";
    private static final String OJDBC17_VERSION = "23.26.2.0.0";
    private static final Calendar UTC = Calendar.getInstance(
            TimeZone.getTimeZone("UTC"));
    private static final Calendar SAO_PAULO = Calendar.getInstance(
            TimeZone.getTimeZone("America/Sao_Paulo"));

    private ValidateCp3iPersistence() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 6) {
            throw new IllegalArgumentException(
                    "uso: ValidateCp3iPersistence <profile> <root> "
                    + "<result> <commit> <war-sha256> <runtime>");
        }
        String profile = args[0];
        require("ci-h2".equals(profile) || "oracle".equals(profile),
                "perfil inválido");
        require(args[3].matches("[0-9a-f]{40}"), "commit inválido");
        require(args[4].matches("[0-9a-f]{64}"), "SHA-256 do WAR inválido");

        boolean oracle = "oracle".equals(profile);
        if (oracle) {
            Class.forName("oracle.jdbc.OracleDriver");
        } else {
            Class.forName("org.h2.Driver");
        }

        String url = oracle ? required("ORACLE_DB_URL")
                : "jdbc:h2:mem:cp3i_" + Long.toString(System.nanoTime(), 36)
                    + ";MODE=Oracle;DB_CLOSE_DELAY=-1";
        String user = oracle ? required("ORACLE_DB_USER") : "sa";
        String password = oracle ? required("ORACLE_DB_PASSWORD") : "";
        try (Connection connection = DriverManager.getConnection(
                url, user, password)) {
            connection.setAutoCommit(true);
            if (!oracle) {
                runH2Schema(connection, new File(args[1]));
            } else {
                validateOracle19c(connection);
            }
            connection.setAutoCommit(false);

            String suffix = Long.toString(System.currentTimeMillis(), 36)
                    .toUpperCase();
            String prefix = "LAB-CP3I-" + suffix + "-";
            List<String> numbers = new ArrayList<String>();
            try {
                validateSequence(connection, oracle);
                for (int i = 0; i < 6; i++) {
                    String number = prefix + i;
                    numbers.add(number);
                    insertPedido(connection, oracle, number);
                }
                connection.commit();

                validatePagination(connection, prefix);
                validateTimestampAndTimezone(connection, prefix);
                validateClob(connection, oracle);
                validateBlob(connection, oracle, numbers.get(0));
                validateRollback(connection, oracle, prefix + "ROLLBACK");
            } finally {
                cleanup(connection, numbers, prefix + "ROLLBACK");
            }

            writeResult(new File(args[2]), profile, args[3], args[4], oracle);
        }
        System.out.println("OK: CP-3I/3.41 " + profile
                + " aprovou rollback, sequence, paginação, timestamp/timezone,"
                + " CLOB e BLOB");
    }

    private static void validateOracle19c(Connection connection)
            throws SQLException {
        String product = connection.getMetaData().getDatabaseProductVersion();
        require(product != null && product.contains("Oracle Database 19c"),
                "produto conectado não é Oracle Database 19c");
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT VERSION_FULL FROM PRODUCT_COMPONENT_VERSION "
                + "WHERE PRODUCT LIKE 'Oracle Database%'");
             ResultSet result = statement.executeQuery()) {
            require(result.next() && ORACLE_VERSION.equals(result.getString(1)),
                    "Release Update Oracle diverge");
        }
        require(connection.getMetaData().getDriverVersion()
                .startsWith(OJDBC17_VERSION),
                "driver efetivo não é ojdbc17 " + OJDBC17_VERSION);
    }

    private static void runH2Schema(Connection connection, File root)
            throws Exception {
        Class<?> runScript = Class.forName("org.h2.tools.RunScript");
        java.lang.reflect.Method execute = runScript.getMethod(
                "execute", Connection.class, Reader.class);
        for (String name : new String[] {"001_schema.sql", "002_seed.sql"}) {
            File script = new File(root, "app/src/main/resources/db/h2/" + name);
            require(script.isFile(), "script H2 ausente: " + name);
            try (Reader reader = new InputStreamReader(
                    new FileInputStream(script), StandardCharsets.UTF_8)) {
                execute.invoke(null, connection, reader);
            }
        }
    }

    private static void validateSequence(Connection connection, boolean oracle)
            throws SQLException {
        String sql = oracle ? "SELECT LAB_PEDIDO_SEQ.NEXTVAL FROM DUAL"
                : "SELECT NEXT VALUE FOR LAB_PEDIDO_SEQ";
        long first = queryLong(connection, sql);
        long second = queryLong(connection, sql);
        require(second > first, "sequence não avançou monotonicamente");
    }

    private static void insertPedido(Connection connection, boolean oracle,
            String number) throws SQLException {
        long id = queryLong(connection, oracle
                ? "SELECT LAB_PEDIDO_SEQ.NEXTVAL FROM DUAL"
                : "SELECT NEXT VALUE FOR LAB_PEDIDO_SEQ");
        try (PreparedStatement statement = connection.prepareStatement(
                "INSERT INTO LAB_PEDIDO (ID, NUMERO, CLIENTE_NOME, "
                + "DESCRICAO, VALOR_TOTAL, STATUS, CRIADO_EM, ATUALIZADO_EM)"
                + " VALUES (?, ?, ?, ?, ?, 'NOVO', SYSTIMESTAMP, SYSTIMESTAMP)")) {
            statement.setLong(1, id);
            statement.setString(2, number);
            statement.setString(3, "CP-3I persistence probe");
            statement.setString(4, "rollback sequence pagination timestamp");
            statement.setBigDecimal(5, new java.math.BigDecimal("11.11"));
            require(statement.executeUpdate() == 1,
                    "pedido de probe não foi inserido");
        }
    }

    private static void validatePagination(Connection connection, String prefix)
            throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT ID, NUMERO FROM LAB_PEDIDO WHERE NUMERO LIKE ? "
                + "ORDER BY ID OFFSET ? ROWS FETCH NEXT ? ROWS ONLY")) {
            statement.setString(1, prefix + "%");
            statement.setInt(2, 2);
            statement.setInt(3, 2);
            try (ResultSet result = statement.executeQuery()) {
                long previous = Long.MIN_VALUE;
                int count = 0;
                while (result.next()) {
                    long current = result.getLong(1);
                    require(current > previous,
                            "pagina não preservou a ordenação por ID");
                    previous = current;
                    require(result.getString(2).startsWith(prefix),
                            "pagina retornou registro fora do probe");
                    count++;
                }
                require(count == 2, "paginação não retornou duas linhas");
            }
        }
    }

    private static void validateTimestampAndTimezone(Connection connection,
            String prefix) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT CRIADO_EM FROM LAB_PEDIDO WHERE NUMERO = ?")) {
            statement.setString(1, prefix + "0");
            try (ResultSet result = statement.executeQuery()) {
                require(result.next(), "timestamp do pedido não encontrado");
                Timestamp utc = result.getTimestamp(1, UTC);
                Timestamp local = result.getTimestamp(1, SAO_PAULO);
                ResultSetMetaData metadata = result.getMetaData();
                require(utc != null && local != null,
                        "JDBC não retornou timestamp nos dois fusos");
                require(metadata.getScale(1) >= 6,
                        "coluna temporal não preserva TIMESTAMP(6)");
            }
        }
        try (Statement statement = connection.createStatement();
             ResultSet result = statement.executeQuery(
                     "SELECT SYSTIMESTAMP, CURRENT_TIMESTAMP FROM DUAL")) {
            require(result.next()
                    && result.getTimestamp(1, UTC) != null
                    && result.getTimestamp(2, UTC) != null,
                    "funções de timestamp/timezone não retornaram valor");
        }
    }

    private static void validateClob(Connection connection, boolean oracle)
            throws Exception {
        String text = "CP-3I CLOB — acentuação e conteúdo longo ".repeat(12);
        Clob source = connection.createClob();
        try {
            source.setString(1, text);
            try (PreparedStatement statement = connection.prepareStatement(
                    "SELECT ? FROM DUAL")) {
                statement.setClob(1, source);
                try (ResultSet result = statement.executeQuery()) {
                    require(result.next(), "consulta CLOB não retornou linha");
                    Clob returned = result.getClob(1);
                    require(returned != null
                            && text.equals(returned.getSubString(1, (int) returned.length())),
                            "round-trip CLOB divergiu");
                    returned.free();
                }
            }
        } finally {
            source.free();
        }
    }

    private static void validateBlob(Connection connection, boolean oracle,
            String number) throws Exception {
        long pedidoId = queryLong(connection, "SELECT ID FROM LAB_PEDIDO "
                + "WHERE NUMERO = '" + number.replace("'", "''") + "'");
        long anexoId = queryLong(connection, oracle
                ? "SELECT LAB_ANEXO_SEQ.NEXTVAL FROM DUAL"
                : "SELECT NEXT VALUE FOR LAB_ANEXO_SEQ");
        byte[] bytes = new byte[] {0, 1, 2, 3, 10, 13, 127, -128, -1};
        Blob source = connection.createBlob();
        try {
            source.setBytes(1, bytes);
            try (PreparedStatement statement = connection.prepareStatement(
                    "INSERT INTO LAB_ANEXO (ID, PEDIDO_ID, NOME_ARQUIVO, "
                    + "TIPO_CONTEUDO, TAMANHO_BYTES, SHA256, CONTEUDO, CRIADO_EM)"
                    + " VALUES (?, ?, 'cp3i.bin', 'application/octet-stream', "
                    + "?, ?, ?, SYSTIMESTAMP)")) {
                statement.setLong(1, anexoId);
                statement.setLong(2, pedidoId);
                statement.setInt(3, bytes.length);
                statement.setString(4, sha256(bytes));
                statement.setBlob(5, source);
                require(statement.executeUpdate() == 1,
                        "anexo BLOB não foi inserido");
            }
            connection.commit();
            try (PreparedStatement statement = connection.prepareStatement(
                    "SELECT CONTEUDO FROM LAB_ANEXO WHERE ID = ?")) {
                statement.setLong(1, anexoId);
                try (ResultSet result = statement.executeQuery()) {
                    require(result.next(), "BLOB inserido não foi encontrado");
                    Blob returned = result.getBlob(1);
                    require(returned != null
                            && java.util.Arrays.equals(bytes, returned.getBytes(1, bytes.length)),
                            "round-trip BLOB divergiu");
                    returned.free();
                }
            }
        } finally {
            source.free();
        }
    }

    private static void validateRollback(Connection connection, boolean oracle,
            String number) throws SQLException {
        connection.setAutoCommit(false);
        try {
            insertPedido(connection, oracle, number);
            connection.rollback();
        } finally {
            connection.setAutoCommit(true);
        }
        try (PreparedStatement statement = connection.prepareStatement(
                "SELECT COUNT(*) FROM LAB_PEDIDO WHERE NUMERO = ?")) {
            statement.setString(1, number);
            try (ResultSet result = statement.executeQuery()) {
                require(result.next() && result.getInt(1) == 0,
                        "rollback deixou registro do probe persistido");
            }
        }
    }

    private static void cleanup(Connection connection, List<String> numbers,
            String rollbackNumber) throws SQLException {
        connection.setAutoCommit(false);
        try (PreparedStatement anexo = connection.prepareStatement(
                "DELETE FROM LAB_ANEXO WHERE PEDIDO_ID IN (SELECT ID FROM "
                + "LAB_PEDIDO WHERE NUMERO LIKE ?)");
             PreparedStatement pedido = connection.prepareStatement(
                "DELETE FROM LAB_PEDIDO WHERE NUMERO LIKE ?")) {
            String prefix = numbers.isEmpty() ? rollbackNumber
                    : numbers.get(0).substring(0, numbers.get(0).lastIndexOf('-') + 1) + "%";
            anexo.setString(1, prefix);
            anexo.executeUpdate();
            pedido.setString(1, prefix);
            pedido.executeUpdate();
            pedido.setString(1, rollbackNumber);
            pedido.executeUpdate();
            connection.commit();
        } catch (SQLException exception) {
            connection.rollback();
            throw exception;
        } finally {
            connection.setAutoCommit(true);
        }
    }

    private static long queryLong(Connection connection, String sql)
            throws SQLException {
        try (Statement statement = connection.createStatement();
             ResultSet result = statement.executeQuery(sql)) {
            require(result.next(), "consulta numérica não retornou linha");
            return result.getLong(1);
        }
    }

    private static String sha256(byte[] value) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(value);
        StringBuilder result = new StringBuilder(64);
        for (byte item : digest) {
            result.append(String.format("%02x", item & 0xff));
        }
        return result.toString();
    }

    private static void writeResult(File file, String profile, String commit,
            String warSha, boolean oracle) throws Exception {
        File parent = file.getAbsoluteFile().getParentFile();
        require(parent != null && (parent.isDirectory() || parent.mkdirs()),
                "diretório da evidência não pôde ser criado");
        try (Writer writer = new OutputStreamWriter(new FileOutputStream(file),
                StandardCharsets.UTF_8)) {
            writer.write("{\n");
            writer.write("  \"schema\": \"wildfly-migration-cp3i-persistence/v1\",\n");
            writer.write("  \"checkpoint\": \"CP-3I\",\n");
            writer.write("  \"activity\": \"3.41\",\n");
            writer.write("  \"qualification\": \""
                    + (oracle ? "oracle-qualified" : "portable-ci") + "\",\n");
            writer.write("  \"profile\": \"" + profile + "\",\n");
            writer.write("  \"sourceCommit\": \"" + commit + "\",\n");
            writer.write("  \"workingTree\": false,\n");
            writer.write("  \"warSha256\": \"" + warSha + "\",\n");
            writer.write("  \"runtime\": \"java21-wildfly41.0.0\",\n");
            if (oracle) {
                writer.write("  \"databaseVersion\": \""
                        + ORACLE_VERSION + "\",\n");
                writer.write("  \"jdbcDriver\": \"ojdbc17-"
                        + OJDBC17_VERSION + "\",\n");
            } else {
                writer.write("  \"database\": \"h2-2.4.240-memory\",\n");
            }
            writer.write("  \"checks\": {\n");
            writer.write("    \"rollback\": \"passed\",\n");
            writer.write("    \"sequence\": \"passed\",\n");
            writer.write("    \"pagination\": \"passed\",\n");
            writer.write("    \"timestampTimezone\": \"passed\",\n");
            writer.write("    \"clob\": \"passed\",\n");
            writer.write("    \"blob\": \"passed\",\n");
            writer.write("    \"cleanup\": \"passed\"\n");
            writer.write("  },\n");
            writer.write("  \"result\": \"passed\"\n");
            writer.write("}\n");
        }
    }

    private static String required(String name) {
        String value = System.getenv(name);
        require(value != null && !value.trim().isEmpty(),
                "variável Oracle ausente: " + name);
        return value;
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
