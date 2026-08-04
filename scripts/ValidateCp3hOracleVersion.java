import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

/** Read-only Oracle 19c identity probe for CP-3H/3.38. */
public final class ValidateCp3hOracleVersion {
    private ValidateCp3hOracleVersion() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 0) {
            throw new IllegalArgumentException("nenhum argumento é esperado");
        }
        String url = required("ORACLE_DB_URL");
        String user = required("ORACLE_DB_USER");
        String password = required("ORACLE_DB_PASSWORD");
        Class.forName("oracle.jdbc.OracleDriver");
        try (Connection connection = DriverManager.getConnection(
                url, user, password)) {
            String product = connection.getMetaData().getDatabaseProductVersion();
            String driver = connection.getMetaData().getDriverVersion();
            String releaseUpdate;
            try (PreparedStatement statement = connection.prepareStatement(
                    "SELECT VERSION_FULL FROM PRODUCT_COMPONENT_VERSION "
                    + "WHERE PRODUCT LIKE 'Oracle Database%'");
                 ResultSet result = statement.executeQuery()) {
                if (!result.next()) {
                    throw new IllegalStateException("VERSION_FULL não retornou linha");
                }
                releaseUpdate = result.getString(1);
                if (result.next()) {
                    throw new IllegalStateException(
                            "consulta de VERSION_FULL retornou múltiplas linhas");
                }
            }
            require(product.contains("Oracle Database 19c"),
                    "produto conectado não é Oracle Database 19c");
            require("19.3.0.0.0".equals(releaseUpdate),
                    "Release Update divergente: " + releaseUpdate);
            require(driver != null && driver.matches("23\\.26\\.2\\.0\\.0.*"),
                    "ojdbc17 divergente: " + driver);
            System.out.println("databaseProduct=" + oneLine(product));
            System.out.println("databaseVersion=19.3.0.0.0");
            System.out.println("driverVersion=" + oneLine(driver));
        }
    }

    private static String required(String key) {
        String value = System.getenv(key);
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalStateException("configuração Oracle ausente");
        }
        return value;
    }

    private static String oneLine(String value) {
        return value.replace('\r', ' ').replace('\n', ' ').trim();
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
