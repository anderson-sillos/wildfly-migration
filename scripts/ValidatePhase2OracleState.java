import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Arrays;

public final class ValidatePhase2OracleState {
    private static final String DATABASE_VERSION = "19.3.0.0.0";
    private static final String DRIVER_VERSION = "12.1.0.2.0";
    private static final String UPLOAD_SHA256 =
            "8eb0c39e90e87a89c57313d37988ff2a3b67bb43b57ce89956f447a431dc7a3c";

    private ValidatePhase2OracleState() {
    }

    public static void main(String[] args) {
        try {
            run(args);
        } catch (SQLException exception) {
            System.err.println(
                    "FALHA: estado Oracle da fase 2 recusado (SQLState="
                    + safeSqlState(exception.getSQLState())
                    + ", código=" + exception.getErrorCode() + ")");
            System.exit(1);
        } catch (Exception exception) {
            System.err.println(
                    "FALHA: estado Oracle da fase 2 recusado por validação local");
            System.exit(1);
        }
    }

    private static void run(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "uso: ValidatePhase2OracleState "
                    + "<resultado> <commit> <sha256-war>");
        }
        require(args[1].matches("[0-9a-f]{7,40}"),
                "commit inválido");
        require(args[2].matches("[0-9a-f]{64}"),
                "SHA-256 do WAR inválido");

        Class.forName("oracle.jdbc.OracleDriver");
        Connection connection = DriverManager.getConnection(
                requiredEnvironment("ORACLE_DB_URL"),
                requiredEnvironment("ORACLE_DB_USER"),
                requiredEnvironment("ORACLE_DB_PASSWORD"));
        try {
            verifyRuntime(connection);
            verifySchemaObjects(connection);
            verifySeed(connection);
            long contractOrderId = verifyContractOrder(connection);
            verifyContractUpload(connection, contractOrderId);
            verifyContractXml(connection);
            verifyRejectedState(connection);
        } finally {
            connection.close();
        }

        writeResult(new File(args[0]), args[1], args[2]);
        System.out.println(
                "OK: estado Oracle da fase 2 corresponde ao baseline funcional");
    }

    private static void verifyRuntime(Connection connection)
            throws Exception {
        String product =
                connection.getMetaData().getDatabaseProductVersion();
        require(product != null
                && product.indexOf("Oracle Database 19c") >= 0,
                "produto conectado não é Oracle Database 19c");
        require(DRIVER_VERSION.equals(
                connection.getMetaData().getDriverVersion()),
                "versão efetiva do ojdbc7 diverge");

        PreparedStatement statement = connection.prepareStatement(
                "SELECT VERSION_FULL FROM PRODUCT_COMPONENT_VERSION "
                + "WHERE PRODUCT LIKE 'Oracle Database%'");
        try {
            ResultSet result = statement.executeQuery();
            try {
                require(result.next()
                        && DATABASE_VERSION.equals(result.getString(1)),
                        "Release Update Oracle diverge");
                require(!result.next(),
                        "consulta da versão Oracle não é determinística");
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static void verifySchemaObjects(Connection connection)
            throws Exception {
        require(count(connection,
                "SELECT COUNT(*) FROM USER_TABLES "
                + "WHERE TABLE_NAME IN ('LAB_ANEXO', 'LAB_PEDIDO')") == 2L,
                "tabelas canônicas ausentes");
        require(count(connection,
                "SELECT COUNT(*) FROM USER_SEQUENCES "
                + "WHERE SEQUENCE_NAME IN "
                + "('LAB_ANEXO_SEQ', 'LAB_PEDIDO_SEQ')") == 2L,
                "sequences canônicas ausentes");
        require(count(connection,
                "SELECT COUNT(*) FROM USER_INDEXES "
                + "WHERE INDEX_NAME = 'IX_LAB_ANEXO_PEDIDO' "
                + "AND TABLE_NAME = 'LAB_ANEXO'") == 1L,
                "índice canônico ausente");
    }

    private static void verifySeed(Connection connection)
            throws Exception {
        PreparedStatement statement = connection.prepareStatement(
                "SELECT CLIENTE_NOME, DESCRICAO, VALOR_TOTAL, STATUS, "
                + "CRIADO_EM, ATUALIZADO_EM FROM LAB_PEDIDO "
                + "WHERE NUMERO = 'LAB-0001'");
        try {
            ResultSet result = statement.executeQuery();
            try {
                require(result.next(), "seed LAB-0001 ausente");
                require("Cliente de referência".equals(result.getString(1)),
                        "cliente do seed diverge");
                require("Pedido mínimo para validar o baseline".equals(
                        result.getString(2)), "descrição do seed diverge");
                require(new BigDecimal("125.50").compareTo(
                        result.getBigDecimal(3)) == 0,
                        "valor do seed diverge");
                require("NOVO".equals(result.getString(4)),
                        "status do seed diverge");
                require(result.getTimestamp(5) != null
                        && result.getTimestamp(6) != null,
                        "timestamps do seed ausentes");
                require(!result.next(), "seed LAB-0001 duplicado");
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static long verifyContractOrder(Connection connection)
            throws Exception {
        PreparedStatement statement = connection.prepareStatement(
                "SELECT ID, CLIENTE_NOME, DESCRICAO, VALOR_TOTAL, STATUS "
                + "FROM LAB_PEDIDO WHERE NUMERO LIKE 'LAB-SMOKE-C-%'");
        try {
            ResultSet result = statement.executeQuery();
            try {
                require(result.next(), "pedido HTTP do contrato ausente");
                long id = result.getLong(1);
                require(id > 0L, "ID do pedido HTTP inválido");
                require("Cliente contrato".equals(result.getString(2)),
                        "cliente do pedido HTTP diverge");
                require("Pedido criado pela suíte externa".equals(
                        result.getString(3)),
                        "descrição do pedido HTTP diverge");
                require(new BigDecimal("19.75").compareTo(
                        result.getBigDecimal(4)) == 0,
                        "valor do pedido HTTP diverge");
                require("NOVO".equals(result.getString(5)),
                        "status do pedido HTTP diverge");
                require(!result.next(),
                        "mais de um pedido HTTP transitório foi encontrado");
                return id;
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static void verifyContractUpload(
            Connection connection, long pedidoId) throws Exception {
        PreparedStatement statement = connection.prepareStatement(
                "SELECT NOME_ARQUIVO, TIPO_CONTEUDO, TAMANHO_BYTES, "
                + "RTRIM(SHA256), CONTEUDO, CRIADO_EM FROM LAB_ANEXO "
                + "WHERE PEDIDO_ID = ?");
        try {
            statement.setLong(1, pedidoId);
            ResultSet result = statement.executeQuery();
            try {
                require(result.next(), "anexo do contrato ausente");
                require("contrato-upload.txt".equals(result.getString(1)),
                        "nome do anexo diverge");
                require("text/plain".equals(result.getString(2)),
                        "MIME do anexo diverge");
                require(result.getLong(3) == 44L,
                        "tamanho do anexo diverge");
                require(UPLOAD_SHA256.equals(result.getString(4)),
                        "digest do anexo diverge");
                byte[] expected = (
                        "conteúdo portátil da suíte externa CP-1F\n")
                        .getBytes(StandardCharsets.UTF_8);
                require(Arrays.equals(expected, result.getBytes(5)),
                        "BLOB do contrato diverge");
                require(result.getTimestamp(6) != null,
                        "timestamp do anexo ausente");
                require(!result.next(),
                        "mais de um anexo do contrato foi encontrado");
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static void verifyContractXml(Connection connection)
            throws Exception {
        PreparedStatement statement = connection.prepareStatement(
                "SELECT CLIENTE_NOME, DESCRICAO, VALOR_TOTAL, STATUS "
                + "FROM LAB_PEDIDO WHERE NUMERO LIKE 'LAB-SMOKE-X-%'");
        try {
            ResultSet result = statement.executeQuery();
            try {
                require(result.next(), "pedido XML do contrato ausente");
                require("Cliente XML".equals(result.getString(1)),
                        "cliente XML diverge");
                require("Pedido válido usado pelo contrato de importação."
                        .equals(result.getString(2)),
                        "descrição XML diverge");
                require(new BigDecimal("349.90").compareTo(
                        result.getBigDecimal(3)) == 0,
                        "valor XML diverge");
                require("NOVO".equals(result.getString(4)),
                        "status XML diverge");
                require(!result.next(),
                        "mais de um pedido XML transitório foi encontrado");
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static void verifyRejectedState(Connection connection)
            throws Exception {
        require(count(connection,
                "SELECT COUNT(*) FROM LAB_PEDIDO WHERE NUMERO IN "
                + "('XML INVÁLIDO COM ESPAÇOS', "
                + "'XML-VALIDATOR-0001', 'XML-XXE-0001', "
                + "'XML-ENTITY-0001')") == 0L,
                "fixture rejeitada deixou persistência parcial");
    }

    private static long count(Connection connection, String sql)
            throws Exception {
        PreparedStatement statement = connection.prepareStatement(sql);
        try {
            ResultSet result = statement.executeQuery();
            try {
                require(result.next(), "consulta de contagem não retornou");
                long value = result.getLong(1);
                require(!result.next(),
                        "consulta de contagem retornou mais de uma linha");
                return value;
            } finally {
                result.close();
            }
        } finally {
            statement.close();
        }
    }

    private static void writeResult(
            File file, String commit, String warSha256)
            throws Exception {
        File parent = file.getAbsoluteFile().getParentFile();
        require(parent != null
                && (parent.isDirectory() || parent.mkdirs()),
                "diretório do resultado não pôde ser criado");
        Writer writer = new OutputStreamWriter(
                new FileOutputStream(file), "UTF-8");
        try {
            writer.write("{\n");
            writer.write("  \"schema\": "
                    + "\"wildfly-migration-phase2-oracle-state/v1\",\n");
            writer.write("  \"qualification\": \"oracle-qualified\",\n");
            writer.write("  \"profile\": \"oracle\",\n");
            writer.write("  \"commit\": \"" + commit + "\",\n");
            writer.write("  \"sourceCommit\": \"" + commit + "\",\n");
            writer.write("  \"warSha256\": \"" + warSha256 + "\",\n");
            writer.write("  \"runtime\": \"java8-wildfly26.1.3-ee8\",\n");
            writer.write("  \"databaseVersion\": \""
                    + DATABASE_VERSION + "\",\n");
            writer.write("  \"jdbcDriver\": \"ojdbc7-"
                    + DRIVER_VERSION + "\",\n");
            writer.write("  \"contractUploadBytes\": 44,\n");
            writer.write("  \"contractUploadSha256\": \""
                    + UPLOAD_SHA256 + "\",\n");
            writer.write("  \"checks\": {\n");
            writer.write("    \"schemaObjects\": \"passed\",\n");
            writer.write("    \"seedState\": \"passed\",\n");
            writer.write("    \"contractCreate\": \"passed\",\n");
            writer.write("    \"contractUploadBlob\": \"passed\",\n");
            writer.write("    \"contractXml\": \"passed\",\n");
            writer.write("    \"rejectedState\": \"passed\"\n");
            writer.write("  }\n");
            writer.write("}\n");
        } finally {
            writer.close();
        }
    }

    private static String requiredEnvironment(String key) {
        String value = System.getenv(key);
        require(value != null && value.trim().length() > 0,
                "configuração Oracle ausente");
        return value;
    }

    private static String safeSqlState(String value) {
        if (value == null || !value.matches("[A-Za-z0-9]{1,16}")) {
            return "indisponivel";
        }
        return value;
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
