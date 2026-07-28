import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

import javax.xml.XMLConstants;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParserFactory;
import javax.xml.transform.stream.StreamSource;
import javax.xml.validation.Schema;
import javax.xml.validation.SchemaFactory;
import javax.xml.validation.Validator;

import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.XMLReader;
import org.xml.sax.helpers.DefaultHandler;

public final class ValidateXmlFixtures {
    private ValidateXmlFixtures() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("uso: ValidateXmlFixtures <raiz-do-repositorio>");
        }

        File repository = new File(args[0]);
        File schemaFile = file(repository,
                "app/src/main/resources/xsd/pedido-importacao-v1.xsd");
        File validXml = file(repository,
                "contract-tests/fixtures/xml/pedido-valido.xml");
        File invalidXml = file(repository,
                "contract-tests/fixtures/xml/pedido-invalido-xsd.xml");
        File validatorInvalidXml = file(repository,
                "contract-tests/fixtures/xml/"
                + "pedido-invalido-validador.xml");
        File xxeXml = file(repository,
                "contract-tests/fixtures/xml/pedido-xxe.xml");
        File expansionXml = file(repository,
                "contract-tests/fixtures/xml/pedido-entidades-expansivas.xml");

        Schema schema = createSchema(schemaFile);
        validateExpectedValid(schema, validXml);
        validateExpectedValid(schema, validatorInvalidXml);
        validateExpectedInvalid(schema, invalidXml);
        rejectDoctype(xxeXml);
        rejectDoctype(expansionXml);
        System.out.println("OK: XSD e fixtures XML validados");
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        if (!result.isFile()) {
            throw new IllegalArgumentException("arquivo ausente: " + relativePath);
        }
        return result;
    }

    private static Schema createSchema(File schemaFile) throws SAXException {
        SchemaFactory factory =
                SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        setSchemaProperty(factory, XMLConstants.ACCESS_EXTERNAL_DTD, "");
        setSchemaProperty(factory, XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return factory.newSchema(schemaFile);
    }

    private static void setSchemaProperty(
            SchemaFactory factory, String property, String value) throws SAXException {
        try {
            factory.setProperty(property, value);
        } catch (SAXException unsupported) {
            throw new SAXException(
                    "JAXP não suporta a propriedade de segurança " + property,
                    unsupported);
        }
    }

    private static void validateExpectedValid(Schema schema, File xml)
            throws IOException, SAXException {
        Validator validator = secureValidator(schema);
        validator.validate(new StreamSource(xml));
    }

    private static void validateExpectedInvalid(Schema schema, File xml)
            throws IOException, SAXException {
        Validator validator = secureValidator(schema);
        try {
            validator.validate(new StreamSource(xml));
            throw new SAXException("fixture deveria violar o XSD: " + xml);
        } catch (SAXException expected) {
            if (expected.getMessage() != null
                    && expected.getMessage().startsWith("fixture deveria")) {
                throw expected;
            }
        }
    }

    private static Validator secureValidator(Schema schema) throws SAXException {
        Validator validator = schema.newValidator();
        validator.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        validator.setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return validator;
    }

    private static void rejectDoctype(File xml)
            throws IOException, ParserConfigurationException, SAXException {
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
                "http://apache.org/xml/features/nonvalidating/load-external-dtd",
                false);

        XMLReader reader = factory.newSAXParser().getXMLReader();
        reader.setErrorHandler(new DefaultHandler() {
            @Override
            public void fatalError(SAXParseException exception)
                    throws SAXException {
                throw exception;
            }
        });
        InputStream input = new FileInputStream(xml);
        try {
            reader.parse(new InputSource(input));
            throw new SAXException("fixture malicioso deveria ser rejeitado: " + xml);
        } catch (SAXException expected) {
            if (expected.getMessage() != null
                    && expected.getMessage().startsWith("fixture malicioso")) {
                throw expected;
            }
        } finally {
            input.close();
        }
    }
}
