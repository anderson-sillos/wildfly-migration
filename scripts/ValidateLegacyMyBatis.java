import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Reader;
import java.math.BigDecimal;
import java.sql.Connection;
import java.util.Arrays;
import java.util.Date;
import java.util.List;

import br.com.asillos.migration.domain.Anexo;
import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;
import br.com.asillos.migration.persistence.AnexoMapper;
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
import org.h2.tools.RunScript;

public final class ValidateLegacyMyBatis {
    private ValidateLegacyMyBatis() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyMyBatis <raiz-do-repositorio>");
        }

        File repository = new File(args[0]);
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "org.h2.Driver",
                "jdbc:h2:mem:cp1e_mybatis;MODE=Oracle;DB_CLOSE_DELAY=-1",
                "sa",
                "");
        validatePackagedConfiguration();
        runScript(dataSource.getConnection(), file(
                repository,
                "app/src/main/resources/db/h2/001_schema.sql"));
        runScript(dataSource.getConnection(), file(
                repository,
                "app/src/main/resources/db/h2/002_seed.sql"));

        SqlSessionFactory sessionFactory = buildFactory(dataSource);
        try {
            validatePedidoFlow(sessionFactory);
            validateAnexoFlow(sessionFactory);
            validateRollback(sessionFactory);
        } finally {
            runScript(dataSource.getConnection(), file(
                    repository,
                    "app/src/main/resources/db/h2/rollback.sql"));
        }

        System.out.println(
                "OK: mappers, aliases, handler e transações executados no H2");
    }

    private static void validatePackagedConfiguration() throws Exception {
        InputStream input =
                ValidateLegacyMyBatis.class.getClassLoader()
                .getResourceAsStream("mybatis-config.xml");
        require(input != null,
                "mybatis-config.xml não foi empacotado");
        SqlSessionFactory parsed;
        try {
            parsed = new SqlSessionFactoryBuilder().build(
                    input, "syntax-only");
        } finally {
            input.close();
        }

        Configuration configuration = parsed.getConfiguration();
        require(configuration.getEnvironment() == null,
                "validação sintática não deve abrir datasource");
        require(Pedido.class.equals(
                configuration.getTypeAliasRegistry().resolveAlias("pedido")),
                "alias pedido não foi carregado");
        require(Anexo.class.equals(
                configuration.getTypeAliasRegistry().resolveAlias("anexo")),
                "alias anexo não foi carregado");
        require(configuration.getTypeHandlerRegistry()
                .getTypeHandler(StatusPedido.class)
                instanceof StatusPedidoTypeHandler,
                "handler de StatusPedido não foi carregado");
        require(configuration.getTypeHandlerRegistry()
                .getTypeHandler(String.class, JdbcType.CHAR)
                instanceof Sha256TypeHandler,
                "handler de SHA-256 não foi carregado");
        require(configuration.hasStatement(
                "br.com.asillos.migration.persistence.PedidoMapper.listar"),
                "mapper de pedido não foi carregado");
        require(configuration.hasStatement(
                "br.com.asillos.migration.persistence.AnexoMapper.buscarPorId"),
                "mapper de anexo não foi carregado");
    }

    private static SqlSessionFactory buildFactory(
            UnpooledDataSource dataSource) throws Exception {
        Environment environment = new Environment(
                "h2-probe", new JdbcTransactionFactory(), dataSource);
        Configuration configuration = new Configuration(environment);
        configuration.setDatabaseId("h2");
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
            Configuration configuration, String resource) throws Exception {
        InputStream input =
                ValidateLegacyMyBatis.class.getClassLoader()
                .getResourceAsStream(resource);
        if (input == null) {
            throw new IllegalArgumentException(
                    "mapper não encontrado no classpath: " + resource);
        }
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

    private static void validatePedidoFlow(
            SqlSessionFactory sessionFactory) {
        Pedido pedido = new Pedido();
        pedido.setNumero("LAB-CP1E-0001");
        pedido.setClienteNome("Cliente CP-1E");
        pedido.setDescricao("Validação dinâmica do mapper compartilhado");
        pedido.setValorTotal(new BigDecimal("19.90"));

        PedidoRepository repository = new PedidoRepository(sessionFactory);
        Pedido created = repository.criar(pedido);
        require(created != null && created.getId() != null,
                "pedido criado não retornou ID");
        require(StatusPedido.NOVO == created.getStatus(),
                "handler não preservou o status NOVO");
        require(new BigDecimal("19.90").compareTo(
                created.getValorTotal()) == 0,
                "valor monetário divergiu");

        List<Pedido> pedidos = repository.listar();
        require(pedidos.size() == 2,
                "listagem não contém seed e pedido criado");
        require(repository.buscarPorId(created.getId()) != null,
                "consulta por ID não encontrou o pedido criado");
    }

    private static void validateAnexoFlow(
            SqlSessionFactory sessionFactory) {
        final Pedido pedido = new PedidoRepository(sessionFactory).listar().get(1);
        final byte[] content = new byte[] {0, 1, 2, 3, 127, -1};
        final String digest =
                "0123456789abcdef0123456789abcdef"
                + "0123456789abcdef0123456789abcdef";
        final MyBatisTransactionTemplate transactions =
                new MyBatisTransactionTemplate(sessionFactory);

        Long id = transactions.execute(new TransactionWork<Long>() {
            @Override
            public Long execute(SqlSession session) {
                AnexoMapper mapper = session.getMapper(AnexoMapper.class);
                Anexo anexo = new Anexo();
                anexo.setId(mapper.proximoId());
                anexo.setPedidoId(pedido.getId());
                anexo.setNomeArquivo("probe.bin");
                anexo.setTipoConteudo("application/octet-stream");
                anexo.setTamanhoBytes(Long.valueOf(content.length));
                anexo.setSha256(digest);
                anexo.setConteudo(content);
                anexo.setCriadoEm(new Date());
                require(mapper.inserir(anexo) == 1,
                        "inclusão do anexo não afetou uma linha");
                return anexo.getId();
            }
        });

        final Long anexoId = id;
        Anexo stored = transactions.execute(new TransactionWork<Anexo>() {
            @Override
            public Anexo execute(SqlSession session) {
                return session.getMapper(AnexoMapper.class)
                        .buscarPorId(anexoId);
            }
        });
        require(stored != null && Arrays.equals(content, stored.getConteudo()),
                "BLOB do anexo divergiu");
        require(digest.equals(stored.getSha256()),
                "handler não preservou o SHA-256");
    }

    private static void validateRollback(
            SqlSessionFactory sessionFactory) {
        final MyBatisTransactionTemplate transactions =
                new MyBatisTransactionTemplate(sessionFactory);
        try {
            transactions.execute(new TransactionWork<Void>() {
                @Override
                public Void execute(SqlSession session) {
                    PedidoMapper mapper =
                            session.getMapper(PedidoMapper.class);
                    Pedido pedido = new Pedido();
                    pedido.setId(mapper.proximoId());
                    pedido.setNumero("LAB-ROLLBACK");
                    pedido.setClienteNome("Rollback");
                    pedido.setValorTotal(BigDecimal.ZERO);
                    pedido.setStatus(StatusPedido.NOVO);
                    pedido.setCriadoEm(new Date());
                    pedido.setAtualizadoEm(new Date());
                    mapper.inserir(pedido);
                    throw new IllegalStateException("falha intencional");
                }
            });
            throw new IllegalStateException(
                    "falha intencional não interrompeu a transação");
        } catch (IllegalStateException expected) {
            require("falha intencional".equals(expected.getMessage()),
                    "exceção original do rollback não foi preservada");
        }

        Pedido rolledBack = transactions.execute(
                new TransactionWork<Pedido>() {
                    @Override
                    public Pedido execute(SqlSession session) {
                        return session.getMapper(PedidoMapper.class)
                                .buscarPorNumero("LAB-ROLLBACK");
                    }
                });
        require(rolledBack == null,
                "rollback deixou o pedido de teste persistido");
    }

    private static void runScript(
            Connection connection, File script) throws Exception {
        Reader reader = new InputStreamReader(
                new FileInputStream(script), "UTF-8");
        try {
            RunScript.execute(connection, reader);
        } finally {
            reader.close();
            connection.close();
        }
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        require(result.isFile(), "arquivo ausente: " + relativePath);
        return result;
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
