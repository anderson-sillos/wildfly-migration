import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.Date;

import br.com.asillos.migration.domain.Anexo;
import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;
import br.com.asillos.migration.persistence.AnexoRepository;
import br.com.asillos.migration.persistence.MyBatisTransactionTemplate;
import br.com.asillos.migration.persistence.PedidoMapper;
import br.com.asillos.migration.persistence.PedidoRepository;
import br.com.asillos.migration.persistence.Sha256TypeHandler;
import br.com.asillos.migration.persistence.StatusPedidoTypeHandler;
import br.com.asillos.migration.persistence.TransactionWork;

import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.apache.ibatis.type.JdbcType;

public final class ValidateCp2cOraclePersistence {
    private static final String DATABASE_VERSION = "19.3.0.0.0";
    private static final String DRIVER_VERSION = "12.1.0.2.0";

    private ValidateCp2cOraclePersistence() {
    }

    public static void main(String[] args) {
        try {
            run(args);
        } catch (SQLException exception) {
            System.err.println(
                    "FALHA: sonda Oracle recusada (SQLState="
                    + safeSqlState(exception.getSQLState())
                    + ", código=" + exception.getErrorCode() + ")");
            System.exit(1);
        } catch (Exception exception) {
            System.err.println(
                    "FALHA: sonda Oracle recusada por validação local");
            System.exit(1);
        }
    }

    private static void run(String[] args) throws Exception {
        if (args.length != 4) {
            throw new IllegalArgumentException(
                    "uso: ValidateCp2cOraclePersistence "
                    + "<raiz> <resultado> <commit> <sha256-war>");
        }
        require(args[2].matches("[0-9a-f]{7,40}"),
                "commit inválido");
        require(args[3].matches("[0-9a-f]{64}"),
                "SHA-256 do WAR inválido");

        String url = requiredEnvironment("ORACLE_DB_URL");
        String user = requiredEnvironment("ORACLE_DB_USER");
        String password = requiredEnvironment("ORACLE_DB_PASSWORD");
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "oracle.jdbc.OracleDriver", url, user, password);

        String suffix = Long.toString(
                System.currentTimeMillis(), 36).toUpperCase();
        String committedNumber = "LAB-CP2C-Q-" + suffix;
        String rolledBackNumber = "LAB-CP2C-R-" + suffix;
        verifyRuntime(dataSource);
        cleanup(dataSource, committedNumber, rolledBackNumber);

        try {
            SqlSessionFactory sessionFactory =
                    buildFactory(dataSource);
            Pedido created = validateCommitAndTimestamps(
                    sessionFactory, committedNumber);
            validateBlob(sessionFactory, created.getId());
            validateRollback(sessionFactory, rolledBackNumber);
        } finally {
            cleanup(dataSource, committedNumber, rolledBackNumber);
        }

        writeResult(new File(args[1]), args[2], args[3]);
        System.out.println(
                "OK: Oracle 19c qualificou MyBatis, rollback, "
                + "TIMESTAMP(6) e BLOB; dados transitórios removidos");
    }

    private static void verifyRuntime(UnpooledDataSource dataSource)
            throws Exception {
        Connection connection = dataSource.getConnection();
        try {
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
                            "consulta de versão Oracle não é determinística");
                } finally {
                    result.close();
                }
            } finally {
                statement.close();
            }
        } finally {
            connection.close();
        }
    }

    private static SqlSessionFactory buildFactory(
            UnpooledDataSource dataSource) throws Exception {
        Environment environment = new Environment(
                "cp2c-oracle-probe",
                new JdbcTransactionFactory(),
                dataSource);
        Configuration configuration = new Configuration(environment);
        configuration.setDatabaseId("oracle");
        configuration.getTypeAliasRegistry().registerAlias(
                "pedido", Pedido.class);
        configuration.getTypeAliasRegistry().registerAlias(
                "anexo", Anexo.class);
        configuration.getTypeHandlerRegistry().register(
                StatusPedido.class, StatusPedidoTypeHandler.class);
        configuration.getTypeHandlerRegistry().register(
                String.class, JdbcType.CHAR, Sha256TypeHandler.class);
        parseMapper(configuration, "mybatis/PedidoMapper.xml");
        parseMapper(configuration, "mybatis/AnexoMapper.xml");
        return new SqlSessionFactoryBuilder().build(configuration);
    }

    private static void parseMapper(
            Configuration configuration,
            String resource) throws Exception {
        InputStream input = ValidateCp2cOraclePersistence.class
                .getClassLoader().getResourceAsStream(resource);
        require(input != null, "mapper ausente no WAR: " + resource);
        try {
            XMLMapperBuilder builder = new XMLMapperBuilder(
                    input,
                    configuration,
                    resource,
                    configuration.getSqlFragments());
            builder.parse();
        } finally {
            input.close();
        }
    }

    private static Pedido validateCommitAndTimestamps(
            SqlSessionFactory sessionFactory,
            String number) {
        Pedido input = new Pedido();
        input.setNumero(number);
        input.setClienteNome("Qualificação CP-2C");
        input.setDescricao("Round-trip Oracle TIMESTAMP(6)");
        input.setValorTotal(new BigDecimal("29.90"));

        Pedido created =
                new PedidoRepository(sessionFactory).criar(input);
        require(created != null && created.getId() != null,
                "commit MyBatis não retornou pedido");
        require(created.getCriadoEm() != null
                && created.getAtualizadoEm() != null,
                "timestamps Oracle não retornaram");
        require(input.getCriadoEm().getTime()
                == created.getCriadoEm().getTime(),
                "CRIADO_EM perdeu precisão no round-trip");
        require(input.getAtualizadoEm().getTime()
                == created.getAtualizadoEm().getTime(),
                "ATUALIZADO_EM perdeu precisão no round-trip");

        Pedido persisted = new PedidoRepository(
                sessionFactory).buscarPorId(created.getId());
        require(persisted != null
                && number.equals(persisted.getNumero()),
                "commit MyBatis não persistiu o pedido");
        return persisted;
    }

    private static void validateBlob(
            SqlSessionFactory sessionFactory,
            Long pedidoId) {
        byte[] content = new byte[] {
            0, 1, 2, 3, 10, 13, 127, -128, -1
        };
        AnexoRepository repository =
                new AnexoRepository(sessionFactory);
        Anexo created = repository.criar(
                pedidoId,
                "../cp2c-oracle.bin",
                "application/octet-stream",
                content);
        require(created != null && created.getId() != null,
                "BLOB Oracle não retornou anexo");
        require(Arrays.equals(content, created.getConteudo()),
                "conteúdo BLOB divergiu no round-trip");
        require(created.getCriadoEm() != null,
                "timestamp do BLOB não retornou");

        Anexo persisted = repository.buscarPorId(created.getId());
        require(persisted != null
                && Arrays.equals(content, persisted.getConteudo()),
                "nova sessão MyBatis não recuperou o BLOB");
    }

    private static void validateRollback(
            SqlSessionFactory sessionFactory,
            final String number) {
        MyBatisTransactionTemplate transactions =
                new MyBatisTransactionTemplate(sessionFactory);
        try {
            transactions.execute(new TransactionWork<Void>() {
                @Override
                public Void execute(SqlSession session) {
                    PedidoMapper mapper =
                            session.getMapper(PedidoMapper.class);
                    Date now = new Date();
                    Pedido pedido = new Pedido();
                    pedido.setId(mapper.proximoId());
                    pedido.setNumero(number);
                    pedido.setClienteNome("Rollback CP-2C");
                    pedido.setDescricao("Falha intencional após INSERT");
                    pedido.setValorTotal(BigDecimal.ONE);
                    pedido.setStatus(StatusPedido.NOVO);
                    pedido.setCriadoEm(now);
                    pedido.setAtualizadoEm(now);
                    require(mapper.inserir(pedido) == 1,
                            "INSERT de rollback não afetou uma linha");
                    throw new ProbeRollbackException();
                }
            });
            throw new IllegalStateException(
                    "falha intencional não interrompeu a transação");
        } catch (ProbeRollbackException expected) {
            // A mesma exceção atravessou MyBatisTransactionTemplate.
        }

        Pedido rolledBack = transactions.execute(
                new TransactionWork<Pedido>() {
                    @Override
                    public Pedido execute(SqlSession session) {
                        return session.getMapper(PedidoMapper.class)
                                .buscarPorNumero(number);
                    }
                });
        require(rolledBack == null,
                "rollback MyBatis deixou alteração parcial no Oracle");
    }

    private static void cleanup(
            UnpooledDataSource dataSource,
            String firstNumber,
            String secondNumber) throws SQLException {
        Connection connection = dataSource.getConnection();
        try {
            connection.setAutoCommit(false);
            PreparedStatement statement = connection.prepareStatement(
                    "DELETE FROM LAB_ANEXO WHERE PEDIDO_ID IN "
                    + "(SELECT ID FROM LAB_PEDIDO "
                    + "WHERE NUMERO IN (?, ?))");
            try {
                statement.setString(1, firstNumber);
                statement.setString(2, secondNumber);
                statement.executeUpdate();
            } finally {
                statement.close();
            }
            statement = connection.prepareStatement(
                    "DELETE FROM LAB_PEDIDO WHERE NUMERO IN (?, ?)");
            try {
                statement.setString(1, firstNumber);
                statement.setString(2, secondNumber);
                statement.executeUpdate();
            } finally {
                statement.close();
            }
            connection.commit();
        } catch (SQLException exception) {
            try {
                connection.rollback();
            } catch (SQLException ignored) {
                // A falha original será propagada.
            }
            throw exception;
        } finally {
            connection.close();
        }
    }

    private static void writeResult(
            File file,
            String commit,
            String warSha256) throws Exception {
        File parent = file.getAbsoluteFile().getParentFile();
        require(parent != null
                && (parent.isDirectory() || parent.mkdirs()),
                "diretório do resultado não pôde ser criado");
        Writer writer = new OutputStreamWriter(
                new FileOutputStream(file), "UTF-8");
        try {
            writer.write("{\n");
            writer.write("  \"schema\": "
                    + "\"wildfly-migration-oracle-persistence/v1\",\n");
            writer.write("  \"qualification\": \"oracle-qualified\",\n");
            writer.write("  \"profile\": \"oracle\",\n");
            writer.write("  \"commit\": \"" + commit + "\",\n");
            writer.write("  \"warSha256\": \"" + warSha256 + "\",\n");
            writer.write("  \"runtime\": \"java8-wildfly26.1.3-ee8\",\n");
            writer.write("  \"databaseVersion\": \""
                    + DATABASE_VERSION + "\",\n");
            writer.write("  \"jdbcDriver\": \"ojdbc7-"
                    + DRIVER_VERSION + "\",\n");
            writer.write("  \"checks\": {\n");
            writer.write("    \"mybatisCommit\": \"passed\",\n");
            writer.write("    \"mybatisRollback\": \"passed\",\n");
            writer.write("    \"timestampRoundTrip\": \"passed\",\n");
            writer.write("    \"blobRoundTrip\": \"passed\",\n");
            writer.write("    \"transientDataCleanup\": \"passed\"\n");
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

    private static final class ProbeRollbackException
            extends RuntimeException {
        private static final long serialVersionUID = 1L;
    }
}
