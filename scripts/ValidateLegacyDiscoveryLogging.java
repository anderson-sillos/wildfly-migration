import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

public final class ValidateLegacyDiscoveryLogging {
    private ValidateLegacyDiscoveryLogging() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyDiscoveryLogging <raiz>");
        }
        File repository = new File(args[0]);
        String discovery = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/"
                + "validation/LegacyValidatorDiscovery.java"));
        String numberValidator = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/"
                + "validation/NumeroFormatoValidator.java"));
        String moneyValidator = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/"
                + "validation/ValorMonetarioValidator.java"));
        String statusValidator = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/"
                + "validation/StatusInicialValidator.java"));
        String parser = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/xml/"
                + "LegacyPedidoXmlParser.java"));
        String filter = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "RequestContextFilter.java"));
        String servlet = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "XmlImportServlet.java"));
        String uploadServlet = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "UploadServlet.java"));
        String pedidoServlet = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "PedidoServlet.java"));
        String contextListener = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "MigrationContextListener.java"));
        File logConfigurationFile = new File(
                repository, "app/src/main/resources/log4j.properties");
        boolean bridgeActive = !logConfigurationFile.isFile();
        String logConfiguration = bridgeActive
                ? ""
                : read(logConfigurationFile);
        String pom = read(file(repository, "app/pom.xml"));
        String deploymentStructure = read(file(
                repository,
                "app/src/main/webapp/WEB-INF/"
                + "jboss-deployment-structure.xml"));
        String h2Profile = read(file(
                repository,
                "runtime/phase3/java17-wildfly26/profiles/ci-h2.cli"));
        String oracleProfile = read(file(
                repository,
                "runtime/phase3/java17-wildfly26/profiles/oracle.cli"));
        String smoke = read(file(
                repository, "scripts/smoke-wildfly9-datasource.sh"));

        require(discovery.indexOf("new Reflections(configuration)") >= 0
                && discovery.indexOf(
                        "getSubTypesOf(PedidoImportValidator.class)") >= 0,
                "Reflections não descobre os validadores");
        require(discovery.indexOf("ClasspathHelper.forPackage") >= 0
                && discovery.indexOf("addClassLoader(classLoader)") >= 0,
                "classloader do WAR não está explícito na descoberta");
        require(discovery.indexOf("Collections.sort") >= 0
                && discovery.indexOf("left.order()") >= 0
                && discovery.indexOf("getClass().getName()") >= 0,
                "ordenação determinística dos validadores ausente");
        require(numberValidator.indexOf("return 10;") >= 0
                && numberValidator.indexOf(
                        "return \"numero-formato\";") >= 0,
                "contrato do validador de número divergiu");
        require(moneyValidator.indexOf("return 20;") >= 0
                && moneyValidator.indexOf(
                        "return \"valor-monetario\";") >= 0,
                "contrato do validador monetário divergiu");
        require(statusValidator.indexOf("return 30;") >= 0
                && statusValidator.indexOf(
                        "return \"status-inicial\";") >= 0
                && statusValidator.indexOf("StatusPedido.NOVO") >= 0,
                "regra de negócio do status inicial divergiu");
        require(parser.indexOf(
                "LegacyValidatorDiscovery.discover()") >= 0
                && parser.indexOf("validator.validate(pedido)") >= 0,
                "validadores descobertos não são executados");
        require(filter.indexOf(
                "MDC.put(\"correlationId\", correlationId)") >= 0
                && filter.indexOf("MDC.remove(\"correlationId\")") >= 0
                && filter.indexOf("finally") >= 0,
                "correlação de logging não é limpa em finally");
        require(servlet.indexOf(
                "legacy_xml_import accepted") >= 0
                && servlet.indexOf(
                        "legacy_xml_import rejected reason=") >= 0
                && servlet.indexOf(
                        "rejected reason=domain_validator") >= 0,
                "eventos funcionais do fluxo XML não são registrados");
        require(servlet.indexOf("LOGGER.info(xml") < 0
                && servlet.indexOf("LOGGER.warn(xml") < 0,
                "conteúdo XML não pode ser registrado");
        require(callIncludesThrowable(
                    servlet,
                    "LOGGER.error(",
                    "legacy_xml_import persistence_failure")
                && callIncludesThrowable(
                    servlet,
                    "LOGGER.warn(",
                    "legacy_xml_import temporary_cleanup_failure"),
                "falhas internas do XML não preservam a exceção");
        require(callIncludesThrowable(
                    uploadServlet,
                    "LOGGER.error(",
                    "legacy_upload persistence_failure")
                && callIncludesThrowable(
                    uploadServlet,
                    "LOGGER.warn(",
                    "legacy_upload temporary_cleanup_failure"),
                "falhas internas do upload não preservam a exceção");
        require(callIncludesThrowable(
                    pedidoServlet,
                    "LOGGER.error(",
                    "legacy_order persistence_failure"),
                "falha interna de pedido não preserva a exceção");
        require(callIncludesThrowable(
                    contextListener,
                    "new IllegalStateException(",
                    "Falha controlada ao inicializar a persistência"),
                "falha de inicialização não preserva a causa");
        if (bridgeActive) {
            validateBridge(
                    pom, deploymentStructure, h2Profile, oracleProfile);
        } else {
            require(logConfiguration.indexOf(
                    "org.apache.log4j.ConsoleAppender") >= 0
                    && logConfiguration.indexOf("%X{correlationId}") >= 0,
                    "appender ou correlação do Log4j 1 ausente");
        }
        require(smoke.indexOf(
                "legacy_validator_order=numero-formato,"
                + "valor-monetario,status-inicial")
                >= 0
                && smoke.indexOf(
                        "rejected reason=domain_validator") >= 0
                && smoke.indexOf("correlation=$xml_correlation") >= 0,
                "smoke não congela descoberta, regra e correlação");

        System.out.println(bridgeActive
                ? "OK: Reflections e ponte Log4j sobre SLF4J têm contrato"
                  + " determinístico"
                : "OK: Reflections e Log4j 1 têm contrato determinístico");
    }

    private static void validateBridge(
            String pom,
            String deploymentStructure,
            String h2Profile,
            String oracleProfile) {
        require(pom.indexOf("<artifactId>log4j-over-slf4j</artifactId>")
                >= 0
                && pom.indexOf("<slf4j.version>1.7.36</slf4j.version>")
                >= 0,
                "ponte Log4j sobre SLF4J 1.7.36 ausente");
        require(pom.indexOf("<groupId>log4j</groupId>") < 0
                && pom.indexOf("<artifactId>log4j</artifactId>") < 0,
                "Log4j 1 ainda está declarado no POM");
        require(pom.indexOf("<artifactId>slf4j-api</artifactId>") >= 0
                && pom.indexOf("<scope>provided</scope>") >= 0,
                "SLF4J fornecido pelo servidor não está documentado no POM");
        require(deploymentStructure.indexOf(
                "<module name=\"org.apache.log4j\"/>") >= 0,
                "módulo Log4j 1 depreciado do WildFly não foi excluído");
        validateLoggingProfile(h2Profile, "H2");
        validateLoggingProfile(oracleProfile, "Oracle");
    }

    private static void validateLoggingProfile(
            String profile, String profileName) {
        require(profile.indexOf(
                "pattern-formatter=MIGRATION_PATTERN") >= 0
                && profile.indexOf("%X{correlationId}") >= 0
                && profile.indexOf(
                        "logger=br.com.asillos.migration") >= 0,
                "perfil " + profileName
                + " não configura categoria e correlação no WildFly");
    }

    private static boolean callIncludesThrowable(
            String source,
            String call,
            String marker) {
        int offset = 0;
        while (offset < source.length()) {
            int callIndex = source.indexOf(call, offset);
            if (callIndex < 0) {
                return false;
            }
            int callEnd = source.indexOf(");", callIndex);
            if (callEnd < 0) {
                return false;
            }
            String arguments = source.substring(callIndex, callEnd);
            if (arguments.indexOf(marker) >= 0
                    && arguments.indexOf("exception") >= 0) {
                return true;
            }
            offset = callEnd + 2;
        }
        return false;
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        require(result.isFile(), "arquivo ausente: " + relativePath);
        return result;
    }

    private static String read(File file) throws Exception {
        InputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                output.write(buffer, 0, count);
            }
            return new String(
                    output.toByteArray(), Charset.forName("UTF-8"));
        } finally {
            input.close();
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
