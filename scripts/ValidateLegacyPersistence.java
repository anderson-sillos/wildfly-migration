import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

public final class ValidateLegacyPersistence {
    private static final String JNDI_NAME = "java:/jdbc/MigrationDS";

    private ValidateLegacyPersistence() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyPersistence <raiz-do-repositorio>");
        }

        File repository = new File(args[0]);
        validateConfiguration(parse(file(
                repository,
                "app/src/main/resources/mybatis-config.xml")));
        validatePedidoMapper(parse(file(
                repository,
                "app/src/main/resources/mybatis/PedidoMapper.xml")));
        validateAnexoMapper(parse(file(
                repository,
                "app/src/main/resources/mybatis/AnexoMapper.xml")));
        validateTransactionSource(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/persistence/"
                + "MyBatisTransactionTemplate.java"));

        System.out.println(
                "OK: domínio e persistência MyBatis validados estaticamente");
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        require(result.isFile(), "arquivo ausente: " + relativePath);
        return result;
    }

    private static Document parse(File file) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(false);
        factory.setValidating(false);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities",
                false);
        factory.setFeature(
                "http://apache.org/xml/features/nonvalidating/load-external-dtd",
                false);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");

        DocumentBuilder builder = factory.newDocumentBuilder();
        builder.setEntityResolver(new org.xml.sax.EntityResolver() {
            @Override
            public InputSource resolveEntity(
                    String publicId, String systemId) {
                return new InputSource(new java.io.StringReader(""));
            }
        });
        return builder.parse(file);
    }

    private static void validateConfiguration(Document document) {
        Element configuration = document.getDocumentElement();
        require("configuration".equals(configuration.getTagName()),
                "raiz da configuração MyBatis inválida");

        Element environment = unique(document, "environment");
        require("legacy-jndi".equals(environment.getAttribute("id")),
                "environment MyBatis divergente");
        require("legacy-jndi".equals(
                unique(document, "environments").getAttribute("default")),
                "environment padrão divergente");
        require("JDBC".equals(
                unique(document, "transactionManager").getAttribute("type")),
                "MyBatis deve controlar a transação JDBC local");
        require("JNDI".equals(
                unique(document, "dataSource").getAttribute("type")),
                "MyBatis deve obter o datasource por JNDI");

        Element dataSourceProperty = findByAttribute(
                document, "property", "name", "data_source");
        require(JNDI_NAME.equals(dataSourceProperty.getAttribute("value")),
                "nome JNDI do MyBatis divergente");

        requireAlias(document, "pedido",
                "br.com.asillos.migration.domain.Pedido");
        requireAlias(document, "anexo",
                "br.com.asillos.migration.domain.Anexo");

        Element statusHandler = findByAttribute(
                document,
                "typeHandler",
                "handler",
                "br.com.asillos.migration.persistence.StatusPedidoTypeHandler");
        require("br.com.asillos.migration.domain.StatusPedido".equals(
                statusHandler.getAttribute("javaType")),
                "javaType do handler de status divergente");
        Element shaHandler = findByAttribute(
                document,
                "typeHandler",
                "handler",
                "br.com.asillos.migration.persistence.Sha256TypeHandler");
        require("java.lang.String".equals(
                shaHandler.getAttribute("javaType"))
                && "CHAR".equals(shaHandler.getAttribute("jdbcType")),
                "registro do handler SHA-256 divergente");

        Element provider = unique(document, "databaseIdProvider");
        require("DB_VENDOR".equals(provider.getAttribute("type")),
                "databaseIdProvider deve usar os metadados do fornecedor");
        requireProviderValue(provider, "Oracle", "oracle");
        requireProviderValue(provider, "H2", "h2");

        Set<String> expectedMappers = new HashSet<String>(Arrays.asList(
                "mybatis/PedidoMapper.xml",
                "mybatis/AnexoMapper.xml"));
        NodeList mapperNodes = document.getElementsByTagName("mapper");
        Set<String> actualMappers = new HashSet<String>();
        for (int index = 0; index < mapperNodes.getLength(); index++) {
            Element mapper = (Element) mapperNodes.item(index);
            actualMappers.add(mapper.getAttribute("resource"));
        }
        require(expectedMappers.equals(actualMappers),
                "recursos de mapper divergentes");
    }

    private static void requireAlias(
            Document document, String alias, String type) {
        Element element = findByAttribute(
                document, "typeAlias", "alias", alias);
        require(type.equals(element.getAttribute("type")),
                "tipo divergente para alias " + alias);
    }

    private static void requireProviderValue(
            Element provider, String product, String databaseId) {
        NodeList nodes = provider.getElementsByTagName("property");
        for (int index = 0; index < nodes.getLength(); index++) {
            Element property = (Element) nodes.item(index);
            if (product.equals(property.getAttribute("name"))) {
                require(databaseId.equals(property.getAttribute("value")),
                        "databaseId divergente para " + product);
                return;
            }
        }
        throw new IllegalArgumentException(
                "fornecedor ausente no databaseIdProvider: " + product);
    }

    private static void validatePedidoMapper(Document document) {
        validateMapper(
                document,
                "br.com.asillos.migration.persistence.PedidoMapper",
                new String[] {
                    "listar", "buscarPorId", "buscarPorNumero",
                    "inserir", "atualizar"
                },
                "LAB_PEDIDO_SEQ");
        Element resultMap = unique(document, "resultMap");
        require("pedido".equals(resultMap.getAttribute("type")),
                "resultMap de pedido não usa o alias");
        findByAttribute(document, "result", "column", "STATUS");
    }

    private static void validateAnexoMapper(Document document) {
        validateMapper(
                document,
                "br.com.asillos.migration.persistence.AnexoMapper",
                new String[] {"listarPorPedido", "buscarPorId", "inserir"},
                "LAB_ANEXO_SEQ");
        Element resultMap = unique(document, "resultMap");
        require("anexo".equals(resultMap.getAttribute("type")),
                "resultMap de anexo não usa o alias");
        findByAttribute(document, "result", "column", "CONTEUDO");
    }

    private static void validateMapper(
            Document document,
            String namespace,
            String[] commonStatements,
            String sequenceName) {
        Element mapper = document.getDocumentElement();
        require("mapper".equals(mapper.getTagName()),
                "raiz de mapper inválida");
        require(namespace.equals(mapper.getAttribute("namespace")),
                "namespace de mapper divergente");

        for (int index = 0; index < commonStatements.length; index++) {
            Element statement = findStatement(
                    document, commonStatements[index], "");
            String sql = normalized(statement.getTextContent());
            require(!sql.contains(" NEXTVAL")
                    && !sql.contains("NEXT VALUE FOR")
                    && !sql.contains(" FROM DUAL"),
                    "SQL específico vazou para " + commonStatements[index]);
        }

        Element oracle = findStatement(document, "proximoId", "oracle");
        Element h2 = findStatement(document, "proximoId", "h2");
        require(normalized(oracle.getTextContent()).contains(
                sequenceName + ".NEXTVAL FROM DUAL"),
                "sequence Oracle divergente em " + namespace);
        require(normalized(h2.getTextContent()).contains(
                "NEXT VALUE FOR " + sequenceName),
                "sequence H2 divergente em " + namespace);
    }

    private static Element findStatement(
            Document document, String id, String databaseId) {
        String[] tags = {"select", "insert", "update", "delete"};
        Element result = null;
        for (int tagIndex = 0; tagIndex < tags.length; tagIndex++) {
            NodeList nodes = document.getElementsByTagName(tags[tagIndex]);
            for (int index = 0; index < nodes.getLength(); index++) {
                Element element = (Element) nodes.item(index);
                if (id.equals(element.getAttribute("id"))
                        && databaseId.equals(
                                element.getAttribute("databaseId"))) {
                    require(result == null,
                            "statement duplicado: " + id + "/" + databaseId);
                    result = element;
                }
            }
        }
        require(result != null,
                "statement ausente: " + id + "/" + databaseId);
        return result;
    }

    private static void validateTransactionSource(File file) throws Exception {
        byte[] bytes = new byte[(int) file.length()];
        InputStream input = new FileInputStream(file);
        try {
            int offset = 0;
            while (offset < bytes.length) {
                int read = input.read(bytes, offset, bytes.length - offset);
                if (read < 0) {
                    break;
                }
                offset += read;
            }
        } finally {
            input.close();
        }
        String source = new String(bytes, "UTF-8");
        for (String required : new String[] {
                "openSession(false)",
                "session.commit()",
                "session.rollback()",
                "finally",
                "session.close()"
        }) {
            require(source.contains(required),
                    "limite transacional ausente: " + required);
        }
    }

    private static Element unique(Document document, String tagName) {
        NodeList nodes = document.getElementsByTagName(tagName);
        require(nodes.getLength() == 1,
                "elemento deve ocorrer uma vez: " + tagName);
        return (Element) nodes.item(0);
    }

    private static Element findByAttribute(
            Document document,
            String tagName,
            String attribute,
            String value) {
        NodeList nodes = document.getElementsByTagName(tagName);
        Element result = null;
        for (int index = 0; index < nodes.getLength(); index++) {
            Element element = (Element) nodes.item(index);
            if (value.equals(element.getAttribute(attribute))) {
                require(result == null,
                        "elemento duplicado: " + tagName + "/" + value);
                result = element;
            }
        }
        require(result != null,
                "elemento ausente: " + tagName + "/" + value);
        return result;
    }

    private static String normalized(String value) {
        return value.replaceAll("\\s+", " ").trim().toUpperCase();
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
