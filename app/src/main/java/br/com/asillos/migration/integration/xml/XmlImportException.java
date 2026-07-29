package br.com.asillos.migration.integration.xml;

/**
 * Falha funcional e segura do contrato de importação XML.
 */
public class XmlImportException extends Exception {
    private static final long serialVersionUID = 1L;

    public XmlImportException(String message) {
        super(message);
    }

    public XmlImportException(String message, Throwable cause) {
        super(message, cause);
    }
}
