import java.io.File;

import javax.xml.XMLConstants;
import javax.xml.parsers.SAXParserFactory;

import org.dom4j.Document;
import org.dom4j.DocumentException;
import org.dom4j.Element;
import org.dom4j.io.SAXReader;
import org.xml.sax.EntityResolver;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.XMLReader;

/**
 * Executa o contrato de parsing dom4j 2.2.0 com o XMLReader seguro do projeto.
 */
public final class ValidateDom4j22 {
    private static final String NAMESPACE =
            "urn:wildfly-migration:pedido:1";

    private ValidateDom4j22() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "uso: ValidateDom4j22 <válido> <xxe> <expansão>");
        }

        Document document = read(new File(args[0]));
        Element root = document.getRootElement();
        require("pedido".equals(root.getName()),
                "dom4j não preservou o elemento raiz");
        require(NAMESPACE.equals(root.getNamespaceURI()),
                "dom4j não preservou o namespace");
        require("XML-0001".equals(root.elementTextTrim("numero")),
                "dom4j não preservou o conteúdo do documento legítimo");

        requireRejected(new File(args[1]), "XXE");
        requireRejected(new File(args[2]), "expansão de entidade");

        System.out.println("{\"schema\":\"wildfly-migration-dom4j-compatibility/v1\","
                + "\"dom4jVersion\":\"2.2.0\","
                + "\"validDocument\":\"passed\","
                + "\"xxeRejection\":\"passed\","
                + "\"entityExpansionRejection\":\"passed\"}");
    }

    private static Document read(File file) throws Exception {
        SAXReader reader = new SAXReader(secureXmlReader());
        reader.setValidation(false);
        reader.setIncludeInternalDTDDeclarations(false);
        reader.setIncludeExternalDTDDeclarations(false);
        return reader.read(file);
    }

    private static void requireRejected(File file, String label)
            throws Exception {
        try {
            read(file);
            throw new IllegalArgumentException(
                    label + " foi aceito pelo parser seguro");
        } catch (DocumentException expected) {
            // A rejeição pode vir do recurso disallow-doctype-decl ou do
            // EntityResolver, ambos fazem parte do contrato de segurança.
        }
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
        reader.setEntityResolver(new EntityResolver() {
            @Override
            public InputSource resolveEntity(String publicId, String systemId)
                    throws SAXException {
                throw new SAXException(
                        "Resolução de entidade externa bloqueada");
            }
        });
        return reader;
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
