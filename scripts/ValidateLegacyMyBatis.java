import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Reader;
import java.io.Writer;
import java.math.BigDecimal;
import java.sql.Connection;
import java.util.Arrays;
import java.util.Date;
import java.util.List;

import br.com.asillos.migration.domain.Anexo;
import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;
import br.com.asillos.migration.persistence.AnexoMapper;
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
import org.apache.ibatis.reflection.DefaultReflectorFactory;
import org.apache.ibatis.reflection.MetaClass;
import org.apache.ibatis.reflection.MetaObject;
import org.apache.ibatis.reflection.SystemMetaObject;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.apache.ibatis.type.JdbcType;
import org.h2.tools.RunScript;

public final class ValidateLegacyMyBatis {
    private static final String MYBATIS_VERSION = "3.5.19";

    private ValidateLegacyMyBatis() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1 && args.length != 4) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyMyBatis <raiz-do-repositorio> "
                    + "[<resultado> <commit> <sha256-war>]");
        }
        if (args.length == 4) {
            require(args[2].matches("[0-9a-f]{7,40}"),
                    "commit inválido");
            require(args[3].matches("[0-9a-f]{64}"),
                    "SHA-256 do WAR inválido");
        }

        File repository = new File(args[0]);
        UnpooledDataSource dataSource = new UnpooledDataSource(
                "org.h2.Driver",
                "jdbc:h2:mem:cp1e_mybatis;MODE=Oracle;DB_CLOSE_DELAY=-1",
                "sa",
                "");
        validateRuntimeVersion();
        validatePackagedConfiguration();
        validateReflection();
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

        if (args.length == 4) {
            writeResult(new File(args[1]), args[2], args[3]);
        }
        System.out.println(
                "OK: MyBatis 3.5.19, mappers, aliases, type handlers, "
                + "reflexão e transações executados no H2");
    }

    private static void validateRuntimeVersion() {
        String version = SqlSessionFactory.class.getPackage()
                .getImplementationVersion();
        require(MYBATIS_VERSION.equals(version),
                "versão efetiva do MyBatis diverge: " + version);
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

    private static void validateReflection() {
        MetaClass metaClass = MetaClass.forClass(
                Pedido.class, new DefaultReflectorFactory());
        require(metaClass.hasGetter("numero")
                && metaClass.hasSetter("numero"),
                "reflexão não reconheceu a propriedade numero");
        require(String.class.equals(metaClass.getGetterType("numero"))
                && String.class.equals(metaClass.getSetterType("numero")),
                "reflexão inferiu tipo divergente para numero");

        Pedido pedido = new Pedido();
        MetaObject metaObject = SystemMetaObject.forObject(pedido);
        metaObject.setValue("numero", "LAB-REFLECTION");
        require("LAB-REFLECTION".equals(metaObject.getValue("numero"))
                && "LAB-REFLECTION".equals(pedido.getNumero()),
                "reflexão não preservou leitura e escrita da propriedade");
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
                "479c197f47fc60be5d2d073366e5b3580"
                + "e0457be226691396351b06b3c6246d6";
        AnexoRepository repository = new AnexoRepository(sessionFactory);
        Anexo stored = repository.criar(
                pedido.getId(),
                "../probe.bin",
                "APPLICATION/OCTET-STREAM; charset=UTF-8",
                content);

        require("probe.bin".equals(stored.getNomeArquivo()),
                "nome do anexo não foi normalizado");
        require("application/octet-stream".equals(stored.getTipoConteudo()),
                "tipo do anexo não foi normalizado");
        require(stored != null && Arrays.equals(content, stored.getConteudo()),
                "BLOB do anexo divergiu");
        require(digest.equals(stored.getSha256()),
                "SHA-256 calculado no servidor divergiu");
        require(Long.valueOf(content.length).equals(stored.getTamanhoBytes()),
                "tamanho calculado no servidor divergiu");

        List<Anexo> metadata =
                repository.listarPorPedido(pedido.getId());
        require(metadata.size() == 1,
                "listagem de metadados do anexo divergiu");
        require(metadata.get(0).getConteudo() == null,
                "listagem de metadados carregou o BLOB");
        require(repository.buscarPorId(stored.getId()).getConteudo() != null,
                "consulta completa do anexo não carregou o BLOB");
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

    private static void writeResult(
            File file, String commit, String warSha256) throws Exception {
        File parent = file.getAbsoluteFile().getParentFile();
        require(parent != null
                && (parent.isDirectory() || parent.mkdirs()),
                "diretório do resultado não pôde ser criado");
        Writer writer = new OutputStreamWriter(
                new FileOutputStream(file), "UTF-8");
        try {
            writer.write("{\n");
            writer.write("  \"schema\": "
                    + "\"wildfly-migration-mybatis-compatibility/v1\",\n");
            writer.write("  \"qualification\": \"portable-ci\",\n");
            writer.write("  \"profile\": \"ci-h2\",\n");
            writer.write("  \"sourceCommit\": \"" + commit + "\",\n");
            writer.write("  \"warSha256\": \"" + warSha256 + "\",\n");
            writer.write("  \"runtime\": "
                    + "\"java17-wildfly26.1.3-ee8\",\n");
            writer.write("  \"database\": \"h2-2.4.240-memory\",\n");
            writer.write("  \"mybatisVersion\": \""
                    + MYBATIS_VERSION + "\",\n");
            writer.write("  \"checks\": {\n");
            writer.write("    \"mappers\": \"passed\",\n");
            writer.write("    \"aliases\": \"passed\",\n");
            writer.write("    \"typeHandlers\": \"passed\",\n");
            writer.write("    \"reflection\": \"passed\",\n");
            writer.write("    \"mybatisCommit\": \"passed\",\n");
            writer.write("    \"mybatisRollback\": \"passed\"\n");
            writer.write("  }\n");
            writer.write("}\n");
        } finally {
            writer.close();
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
