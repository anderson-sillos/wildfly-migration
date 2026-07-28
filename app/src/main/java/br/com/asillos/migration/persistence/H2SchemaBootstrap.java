package br.com.asillos.migration.persistence;

import java.io.PrintWriter;
import java.io.Reader;
import java.io.StringWriter;
import java.sql.Connection;

import javax.naming.InitialContext;
import javax.sql.DataSource;

import br.com.asillos.migration.LegacyBuildMarker;

import org.apache.ibatis.io.Resources;
import org.apache.ibatis.jdbc.ScriptRunner;

/**
 * Prepara o schema efêmero apenas quando o runtime portátil solicita.
 */
public final class H2SchemaBootstrap {
    public static final String ENABLED_PROPERTY =
            "migration.bootstrap.h2";

    private H2SchemaBootstrap() {
    }

    public static boolean runIfEnabled() {
        if (!"true".equalsIgnoreCase(
                System.getProperty(ENABLED_PROPERTY, "false"))) {
            return false;
        }

        Connection connection = null;
        try {
            Object resource = new InitialContext().lookup(
                    LegacyBuildMarker.DATASOURCE_JNDI_NAME);
            if (!(resource instanceof DataSource)) {
                throw new IllegalStateException(
                        "O recurso JNDI não é um DataSource");
            }

            connection = ((DataSource) resource).getConnection();
            String productName =
                    connection.getMetaData().getDatabaseProductName();
            if (!"H2".equals(productName)) {
                throw new IllegalStateException(
                        "Bootstrap portátil recusado fora do H2");
            }

            ScriptRunner runner = new ScriptRunner(connection);
            runner.setAutoCommit(true);
            runner.setStopOnError(true);
            runner.setLogWriter(new PrintWriter(new StringWriter()));
            runner.setErrorLogWriter(new PrintWriter(new StringWriter()));
            run(runner, "db/h2/001_schema.sql");
            run(runner, "db/h2/002_seed.sql");
            return true;
        } catch (Exception exception) {
            throw new IllegalStateException(
                    "Schema H2 portátil não pôde ser preparado", exception);
        } finally {
            if (connection != null) {
                try {
                    connection.close();
                } catch (Exception ignored) {
                    // O pool descarta a conexão se o fechamento falhar.
                }
            }
        }
    }

    private static void run(ScriptRunner runner, String resource)
            throws Exception {
        Reader reader = Resources.getResourceAsReader(resource);
        try {
            runner.runScript(reader);
        } finally {
            reader.close();
        }
    }
}
