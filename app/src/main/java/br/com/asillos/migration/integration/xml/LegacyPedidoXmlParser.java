package br.com.asillos.migration.integration.xml;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

import javax.xml.XMLConstants;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParserFactory;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;
import br.com.asillos.migration.integration.validation.LegacyValidatorDiscovery;
import br.com.asillos.migration.integration.validation.PedidoImportValidator;

import org.apache.log4j.Logger;
import org.apache.xmlbeans.XmlError;
import org.apache.xmlbeans.XmlException;
import org.apache.xmlbeans.XmlOptions;
import org.dom4j.Document;
import org.dom4j.DocumentException;
import org.dom4j.Element;
import org.dom4j.io.SAXReader;
import org.xml.sax.EntityResolver;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.XMLReader;

import wildflyMigrationPedido1.PedidoDocument;

/**
 * Valida com tipos gerados pelo XMLBeans 5.3.0 e mapeia com dom4j 1.6.1.
 */
public final class LegacyPedidoXmlParser {
    private static final Logger LOGGER =
            Logger.getLogger(LegacyPedidoXmlParser.class);

    public static final String NAMESPACE =
            "urn:wildfly-migration:pedido:1";

    private final List<PedidoImportValidator> validators;

    public LegacyPedidoXmlParser(InputStream schemaInput)
            throws XmlImportException {
        if (schemaInput == null) {
            throw new XmlImportException(
                    "XSD de importação não foi encontrado no WAR");
        }
        try {
            /*
             * O XSD é consumido pelo plugin XMLBeans durante o build. Os
             * tipos compilados carregam o TypeSystemHolder no classpath; não
             * há mais compilação dinâmica do schema no primeiro request.
             */
            schemaInput.close();
        } catch (IOException exception) {
            throw new XmlImportException(
                    "XSD de importação não pôde ser lido", exception);
        }
        validators = LegacyValidatorDiscovery.discover();
        LOGGER.info(
                "legacy_validator_order="
                + LegacyValidatorDiscovery.describe(validators));
    }

    public Pedido parse(byte[] xml) throws XmlImportException {
        if (xml == null || xml.length == 0) {
            throw new XmlImportException("O documento XML está vazio");
        }

        validateWithXmlBeans(xml);
        Pedido pedido = mapWithDom4j(xml);
        for (PedidoImportValidator validator : validators) {
            validator.validate(pedido);
        }
        return pedido;
    }

    private void validateWithXmlBeans(byte[] xml)
            throws XmlImportException {
        List<XmlError> errors = new ArrayList<XmlError>();
        try {
            XmlOptions loadOptions = secureLoadOptions();
            loadOptions.setLoadLineNumbers();
            loadOptions.setErrorListener(errors);
            PedidoDocument document = PedidoDocument.Factory.parse(
                    new ByteArrayInputStream(xml), loadOptions);

            XmlOptions validationOptions = new XmlOptions();
            validationOptions.setErrorListener(errors);
            if (!document.validate(validationOptions)) {
                throw schemaViolation(errors);
            }
        } catch (XmlException exception) {
            throw new XmlImportException(
                    "XML rejeitado: documento malformado ou inseguro",
                    exception);
        } catch (IOException exception) {
            throw new XmlImportException(
                    "XML não pôde ser lido", exception);
        }
    }

    private Pedido mapWithDom4j(byte[] xml) throws XmlImportException {
        try {
            SAXReader reader = new SAXReader(secureXmlReader());
            reader.setValidation(false);
            reader.setIncludeInternalDTDDeclarations(false);
            reader.setIncludeExternalDTDDeclarations(false);
            Document document = reader.read(
                    new ByteArrayInputStream(xml));
            Element root = document.getRootElement();
            if (!"pedido".equals(root.getName())
                    || !NAMESPACE.equals(root.getNamespaceURI())) {
                throw new XmlImportException(
                        "XML não atende ao XSD: elemento raiz inválido");
            }

            Pedido pedido = new Pedido();
            pedido.setNumero(requiredText(root, "numero"));
            pedido.setClienteNome(requiredText(root, "clienteNome"));
            pedido.setDescricao(optionalText(root, "descricao"));
            pedido.setValorTotal(new BigDecimal(
                    requiredText(root, "valorTotal")));
            pedido.setStatus(StatusPedido.valueOf(
                    requiredText(root, "status")));
            return pedido;
        } catch (DocumentException exception) {
            throw new XmlImportException(
                    "XML rejeitado: documento malformado ou inseguro",
                    exception);
        } catch (ParserConfigurationException exception) {
            throw new XmlImportException(
                    "Parser XML seguro não está disponível", exception);
        } catch (SAXException exception) {
            throw new XmlImportException(
                    "Parser XML seguro não está disponível", exception);
        } catch (NumberFormatException exception) {
            throw new XmlImportException(
                    "XML não atende ao XSD: valor monetário inválido",
                    exception);
        } catch (IllegalArgumentException exception) {
            throw new XmlImportException(
                    "XML não atende ao XSD: valor enumerado inválido",
                    exception);
        }
    }

    private String requiredText(Element parent, String name)
            throws XmlImportException {
        String value = optionalText(parent, name);
        if (value == null || value.length() == 0) {
            throw new XmlImportException(
                    "XML não atende ao XSD: campo " + name + " ausente");
        }
        return value;
    }

    private String optionalText(Element parent, String name) {
        Iterator<?> elements = parent.elementIterator();
        while (elements.hasNext()) {
            Element child = (Element) elements.next();
            if (name.equals(child.getName())
                    && NAMESPACE.equals(child.getNamespaceURI())) {
                return child.getTextTrim();
            }
        }
        return null;
    }

    private XmlImportException schemaViolation(List<XmlError> errors) {
        if (!errors.isEmpty()) {
            XmlError error = errors.get(0);
            StringBuilder message = new StringBuilder(
                    "XML não atende ao XSD");
            if (error.getLine() > 0) {
                message.append(" (linha ").append(error.getLine());
                if (error.getColumn() > 0) {
                    message.append(", coluna ").append(error.getColumn());
                }
                message.append(')');
            }
            if (error.getMessage() != null) {
                message.append(": ").append(error.getMessage());
            }
            return new XmlImportException(message.toString());
        }
        return new XmlImportException("XML não atende ao XSD");
    }

    private XmlOptions secureLoadOptions() throws XmlImportException {
        try {
            XmlOptions options = new XmlOptions();
            options.setLoadUseXMLReader(secureXmlReader());
            options.setEntityResolver(rejectingEntityResolver());
            return options;
        } catch (ParserConfigurationException exception) {
            throw new XmlImportException(
                    "Parser XML seguro não está disponível", exception);
        } catch (SAXException exception) {
            throw new XmlImportException(
                    "Parser XML seguro não está disponível", exception);
        }
    }

    private XMLReader secureXmlReader()
            throws ParserConfigurationException, SAXException {
        SAXParserFactory factory = SAXParserFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl",
                true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities",
                false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities",
                false);
        factory.setFeature(
                "http://apache.org/xml/features/nonvalidating/"
                + "load-external-dtd",
                false);
        XMLReader reader = factory.newSAXParser().getXMLReader();
        reader.setEntityResolver(rejectingEntityResolver());
        return reader;
    }

    private EntityResolver rejectingEntityResolver() {
        return new EntityResolver() {
            @Override
            public InputSource resolveEntity(
                    String publicId, String systemId) throws SAXException {
                throw new SAXException(
                        "Resolução de entidade externa bloqueada");
            }
        };
    }
}
