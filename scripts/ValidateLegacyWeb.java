import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public final class ValidateLegacyWeb {
    private static final String JAVA_EE_NAMESPACE =
            "http://java.sun.com/xml/ns/j2ee";

    private ValidateLegacyWeb() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyWeb <raiz-do-repositorio>");
        }
        File repository = new File(args[0]);
        validateWebXml(parse(file(
                repository, "app/src/main/webapp/WEB-INF/web.xml")));
        validateTld(parse(file(
                repository, "app/src/main/webapp/WEB-INF/migration.tld")));
        validateTiles(repository);
        validateJsp(repository);
        validateTag(repository);
        System.out.println("OK: Servlets, sessão, Tiles, JSP/JSTL e TLD 2.0 validados");
    }

    private static void validateWebXml(Document document) {
        Element root = document.getDocumentElement();
        require(JAVA_EE_NAMESPACE.equals(root.getNamespaceURI()),
                "namespace legado do web.xml divergente");
        require("2.4".equals(root.getAttribute("version")),
                "web.xml deve continuar em Servlet 2.4");
        require(countText(document, "listener-class",
                "org.apache.tiles.web.startup.TilesListener") == 1,
                "TilesListener deve ocorrer uma vez");
        require(countText(document, "listener-class",
                "br.com.asillos.migration.web.MigrationContextListener") == 1,
                "listener da aplicação deve ocorrer uma vez");
        require(countText(document, "filter-class",
                "br.com.asillos.migration.web.RequestContextFilter") == 1,
                "filtro de contexto deve ocorrer uma vez");
        require(countText(document, "servlet-class",
                "br.com.asillos.migration.web.HealthServlet") == 1,
                "HealthServlet deve ocorrer uma vez");
        require(countText(document, "servlet-class",
                "br.com.asillos.migration.web.PedidoServlet") == 1,
                "PedidoServlet deve ocorrer uma vez");
        require(countText(document, "servlet-class",
                "br.com.asillos.migration.web.PreferenceServlet") == 1,
                "PreferenceServlet deve ocorrer uma vez");
        require(countText(document, "url-pattern", "/health") == 1,
                "mapeamento /health ausente");
        require(countText(document, "url-pattern", "/pedidos/*") == 1,
                "mapeamento /pedidos/* ausente");
        require(countText(document, "url-pattern", "/preferencia") == 1,
                "mapeamento /preferencia ausente");
        require(countText(document, "session-timeout", "30") == 1,
                "timeout de sessão divergente");
    }

    private static void validateTld(Document document) {
        Element root = document.getDocumentElement();
        require("taglib".equals(root.getLocalName()),
                "raiz do TLD inválida");
        require(JAVA_EE_NAMESPACE.equals(root.getNamespaceURI()),
                "namespace histórico do TLD divergente");
        require("2.0".equals(root.getAttribute("version")),
                "descritor deve continuar no TLD 2.0");
        require(countText(document, "tlib-version", "1.0") == 1,
                "tlib-version divergente");
        require(countText(document, "uri",
                "http://asillos.com.br/migration/tags") == 1,
                "URI do TLD divergente");
        require(countText(document, "tag-class",
                "br.com.asillos.migration.web.tag.StatusPedidoTag") == 1,
                "handler do TLD divergente");
        require(countText(document, "body-content", "empty") == 1,
                "tag de status não deve aceitar corpo");
    }

    private static void validateTiles(File repository) throws Exception {
        String definitions = read(file(
                repository, "app/src/main/webapp/WEB-INF/tiles-defs.xml"));
        require(definitions.indexOf(
                "-//Apache Software Foundation//DTD Tiles Configuration 2.0//EN")
                >= 0, "DTD do Tiles 2.0 ausente");
        require(definitions.indexOf("name=\"pedidos.lista\"") >= 0,
                "definição Tiles da lista ausente");
        require(definitions.indexOf("name=\"pedidos.formulario\"") >= 0,
                "definição Tiles do formulário ausente");
        require(definitions.indexOf("name=\"pedidos.detalhe\"") >= 0,
                "definição Tiles do detalhe ausente");
        require(definitions.indexOf("name=\"migration.erro\"") >= 0,
                "definição Tiles do erro ausente");
    }

    private static void validateJsp(File repository) throws Exception {
        String[] files = {
            "app/src/main/webapp/WEB-INF/layout/base.jsp",
            "app/src/main/webapp/WEB-INF/layout/header.jsp",
            "app/src/main/webapp/WEB-INF/layout/footer.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/lista.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/lista-content.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/formulario.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/formulario-content.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/detalhe.jsp",
            "app/src/main/webapp/WEB-INF/views/pedidos/detalhe-content.jsp",
            "app/src/main/webapp/WEB-INF/views/erro.jsp",
            "app/src/main/webapp/WEB-INF/views/erro-content.jsp"
        };
        String combined = "";
        for (int index = 0; index < files.length; index++) {
            combined += read(file(repository, files[index]));
        }
        require(combined.indexOf(
                "http://java.sun.com/jsp/jstl/core") >= 0,
                "JSTL core não foi usada");
        require(combined.indexOf(
                "http://java.sun.com/jsp/jstl/fmt") >= 0,
                "JSTL fmt não foi usada");
        require(combined.indexOf(
                "http://tiles.apache.org/tags-tiles") >= 0,
                "taglib JSP do Tiles não foi usada");
        require(combined.indexOf(
                "http://asillos.com.br/migration/tags") >= 0,
                "TLD customizado não foi usado");
        require(combined.indexOf("data-page=\"pedidos-lista\"") >= 0,
                "marcador de smoke da lista ausente");
        require(combined.indexOf("data-page=\"pedidos-formulario\"") >= 0,
                "marcador de smoke do formulário ausente");
        require(combined.indexOf("data-page=\"pedido-detalhe\"") >= 0,
                "marcador de smoke do detalhe ausente");
    }

    private static void validateTag(File repository) throws Exception {
        String source = read(file(repository,
                "app/src/main/java/br/com/asillos/migration/web/tag/"
                + "StatusPedidoTag.java"));
        require(source.indexOf(
                "import javax.servlet.jsp.tagext.SimpleTagSupport;") >= 0,
                "handler deve usar javax.servlet.jsp.tagext");
        require(source.indexOf("extends SimpleTagSupport") >= 0,
                "handler deve implementar o contrato TLD 2.0");
    }

    private static Document parse(File file) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities", false);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return factory.newDocumentBuilder().parse(file);
    }

    private static int countText(
            Document document, String localName, String expected) {
        NodeList nodes = document.getElementsByTagNameNS("*", localName);
        int matches = 0;
        for (int index = 0; index < nodes.getLength(); index++) {
            Node node = nodes.item(index);
            if (expected.equals(node.getTextContent().trim())) {
                matches++;
            }
        }
        return matches;
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
