import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.SAXParserFactory;
import javax.xml.stream.XMLInputFactory;
import javax.xml.transform.TransformerFactory;

/**
 * Confirma que as APIs XML usadas pelo gate Java 17 são fornecidas por
 * java.xml, sem depender de JARs XML duplicados no classpath da aplicação.
 */
public final class ValidateJavaXmlModule {
    private ValidateJavaXmlModule() {
    }

    public static void main(String[] args) throws Exception {
        requireModule(XMLConstants.class, "XMLConstants");
        requireModule(DocumentBuilderFactory.class, "DocumentBuilderFactory");
        requireModule(SAXParserFactory.class, "SAXParserFactory");
        requireModule(XMLInputFactory.class, "XMLInputFactory");
        requireModule(TransformerFactory.class, "TransformerFactory");

        DocumentBuilderFactory.newInstance();
        SAXParserFactory.newInstance();
        XMLInputFactory.newFactory();
        TransformerFactory.newInstance();

        System.out.println("{"
                + "\"javaFeature\":" + Runtime.version().feature() + ","
                + "\"apiModule\":\"java.xml\","
                + "\"xmlConstants\":\"passed\","
                + "\"dom\":\"passed\","
                + "\"sax\":\"passed\","
                + "\"stax\":\"passed\","
                + "\"jaxpTransform\":\"passed\""
                + "}");
    }

    private static void requireModule(Class<?> type, String label) {
        Module module = type.getModule();
        if (!"java.xml".equals(module.getName())) {
            throw new IllegalStateException(label + " veio de "
                    + module.getName());
        }
    }
}
