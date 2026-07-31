import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;
import java.util.ArrayList;
import java.util.List;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;

import org.apache.xmlbeans.XmlError;
import org.apache.xmlbeans.XmlException;
import org.apache.xmlbeans.XmlOptions;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.xml.sax.EntityResolver;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.XMLReader;
import javax.xml.parsers.SAXParserFactory;

import wildflyMigrationPedido1.PedidoDocument;
import wildflyMigrationPedido1.PedidoImportacaoType;

/**
 * Executa o contrato da atividade 3.11 sem depender do WildFly ou do banco.
 */
public final class ValidateXmlBeans53 {
    private static final String NAMESPACE =
            "urn:wildfly-migration:pedido:1";

    private ValidateXmlBeans53() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            throw new IllegalArgumentException(
                    "uso: ValidateXmlBeans53 <fixture-valida> "
                    + "<fixture-invalida>");
        }

        byte[] validBytes = read(new File(args[0]));
        byte[] invalidBytes = read(new File(args[1]));
        XmlOptions secureOptions = secureOptions();

        List<XmlError> errors = new ArrayList<XmlError>();
        secureOptions.setErrorListener(errors);
        PedidoDocument document = PedidoDocument.Factory.parse(
                new ByteArrayInputStream(validBytes), secureOptions);
        require(document.validate(), "fixture válida não passou no schema");

        PedidoImportacaoType pedido = document.getPedido();
        require(pedido != null, "elemento pedido não foi gerado");
        require("XML-0001".equals(pedido.getNumero()),
                "tipo gerado perdeu o número do pedido");
        require("NOVO".equals(pedido.getStatus().toString()),
                "tipo enumerado gerado perdeu o status");
        require(NAMESPACE.equals(pedido.schemaType().getName().getNamespaceURI()),
                "namespace do tipo gerado divergiu");

        String serialized = document.xmlText(new XmlOptions()
                .setSavePrettyPrint()
                .setSaveAggressiveNamespaces());
        Document serializedDom = parseDom(serialized.getBytes("UTF-8"));
        Element root = serializedDom.getDocumentElement();
        require("pedido".equals(root.getLocalName()),
                "serialização perdeu o elemento raiz");
        require(NAMESPACE.equals(root.getNamespaceURI()),
                "serialização perdeu o namespace do XSD");

        PedidoDocument roundTrip = PedidoDocument.Factory.parse(
                new ByteArrayInputStream(serialized.getBytes("UTF-8")),
                secureOptions());
        require(roundTrip.validate(),
                "documento serializado não passou no schema no round-trip");
        require("XML-0001".equals(roundTrip.getPedido().getNumero()),
                "round-trip perdeu valor de elemento gerado");

        boolean invalidRejected = false;
        try {
            List<XmlError> invalidErrors = new ArrayList<XmlError>();
            XmlOptions invalidOptions = secureOptions();
            invalidOptions.setErrorListener(invalidErrors);
            PedidoDocument invalid = PedidoDocument.Factory.parse(
                    new ByteArrayInputStream(invalidBytes), invalidOptions);
            invalidRejected = !invalid.validate();
        } catch (XmlException expected) {
            invalidRejected = true;
        }
        require(invalidRejected, "fixture inválida foi aceita pelo schema");

        System.out.println("{\"schema\":\"wildfly-migration-xmlbeans-compatibility/v1\","
                + "\"xmlbeansVersion\":\"5.3.0\","
                + "\"generatedPackage\":\"wildflyMigrationPedido1\","
                + "\"validFixture\":\"passed\","
                + "\"schemaRejection\":\"passed\","
                + "\"namespaceRoundTrip\":\"passed\","
                + "\"serializationRoundTrip\":\"passed\"}");
    }

    private static XmlOptions secureOptions() throws Exception {
        XmlOptions options = new XmlOptions();
        options.setLoadUseXMLReader(secureXmlReader());
        options.setEntityResolver(rejectingEntityResolver());
        return options;
    }

    private static XMLReader secureXmlReader() throws Exception {
        SAXParserFactory factory = SAXParserFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature(
                "http://apache.org/xml/features/nonvalidating/"
                + "load-external-dtd", false);
        XMLReader reader = factory.newSAXParser().getXMLReader();
        reader.setEntityResolver(rejectingEntityResolver());
        return reader;
    }

    private static EntityResolver rejectingEntityResolver() {
        return new EntityResolver() {
            @Override
            public InputSource resolveEntity(String publicId, String systemId)
                    throws SAXException {
                throw new SAXException(
                        "Resolução de entidade externa bloqueada");
            }
        };
    }

    private static Document parseDom(byte[] bytes) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature(
                "http://apache.org/xml/features/nonvalidating/"
                + "load-external-dtd", false);
        factory.setXIncludeAware(false);
        factory.setExpandEntityReferences(false);
        return factory.newDocumentBuilder().parse(
                new ByteArrayInputStream(bytes));
    }

    private static byte[] read(File file) throws Exception {
        require(file.isFile(), "fixture ausente: " + file);
        InputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                output.write(buffer, 0, count);
            }
            return output.toByteArray();
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
