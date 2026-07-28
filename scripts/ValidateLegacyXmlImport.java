import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

public final class ValidateLegacyXmlImport {
    private ValidateLegacyXmlImport() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyXmlImport <raiz-do-repositorio>");
        }
        File repository = new File(args[0]);
        String pom = read(file(repository, "app/pom.xml"));
        String parser = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/integration/xml/"
                + "LegacyPedidoXmlParser.java"));
        String servlet = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "XmlImportServlet.java"));
        String pedidoRepository = read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/persistence/"
                + "PedidoRepository.java"));
        String webXml = read(file(
                repository, "app/src/main/webapp/WEB-INF/web.xml"));
        String detail = read(file(
                repository,
                "app/src/main/webapp/WEB-INF/views/pedidos/"
                + "detalhe-content.jsp"));
        String importForm = read(file(
                repository,
                "app/src/main/webapp/WEB-INF/views/pedidos/"
                + "importacao-xml-content.jsp"));
        String schema = read(file(
                repository,
                "app/src/main/resources/xsd/pedido-importacao-v1.xsd"));

        require(pom.indexOf(
                "<xmlbeans.version>2.3.0</xmlbeans.version>") >= 0,
                "XMLBeans 2.3.0 não está fixado");
        require(pom.indexOf(
                "<dom4j.version>1.6.1</dom4j.version>") >= 0,
                "dom4j 1.6.1 não está fixado");
        require(parser.indexOf("XmlBeans.loadXsd") >= 0
                && parser.indexOf("document.validate") >= 0,
                "parser não valida o documento com XMLBeans");
        require(parser.indexOf("new SAXReader(secureXmlReader())") >= 0,
                "parser não mapeia com dom4j e XMLReader seguro");
        require(parser.indexOf("disallow-doctype-decl") >= 0
                && parser.indexOf("external-general-entities") >= 0
                && parser.indexOf("external-parameter-entities") >= 0
                && parser.indexOf("load-external-dtd") >= 0,
                "proteções contra DTD e entidades externas incompletas");
        require(servlet.indexOf("MAX_XML_BYTES = 128 * 1024") >= 0,
                "limite de 128 KiB do XML ausente");
        require(servlet.indexOf(
                "MAX_MULTIPART_REQUEST_BYTES = 160L * 1024L") >= 0
                && servlet.indexOf(
                        "ServletFileUpload.isMultipartContent(request)") >= 0
                && servlet.indexOf("item.delete()") >= 0,
                "seleção multipart, limite ou limpeza estão incompletos");
        require(servlet.indexOf("application/xml") >= 0
                && servlet.indexOf("text/xml") >= 0,
                "tipos de mídia do contrato XML ausentes");

        int parsePosition = servlet.indexOf("parser.parse(xml)");
        int persistPosition = servlet.indexOf(".importar(pedido)");
        require(parsePosition >= 0 && persistPosition > parsePosition,
                "persistência deve ocorrer somente após validação completa");
        require(pedidoRepository.indexOf(
                "public Pedido importar(final Pedido pedido)") >= 0,
                "repositório não preserva o status do pedido importado");
        require(webXml.indexOf("/pedidos/importar-xml") >= 0
                && webXml.indexOf(
                        "br.com.asillos.migration.web.XmlImportServlet") >= 0,
                "endpoint de importação XML ausente");
        require(detail.indexOf("data-xml-import-status=\"ok\"") >= 0,
                "marcador de sucesso da importação ausente");
        require(importForm.indexOf(
                "enctype=\"multipart/form-data\"") >= 0
                && importForm.indexOf("name=\"arquivoXml\"") >= 0
                && importForm.indexOf(
                        "data-page=\"pedidos-importacao-xml\"") >= 0,
                "página de seleção do arquivo XML ausente");
        require(schema.indexOf("[A-Za-z0-9._\\-]*") >= 0,
                "hífen do pattern deve estar escapado para XMLBeans 2.3.0");

        System.out.println(
                "OK: importação XMLBeans/dom4j, XSD e proteções validadas");
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
