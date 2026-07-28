package br.com.asillos.migration.integration.validation;

import br.com.asillos.migration.integration.xml.XmlImportException;

/**
 * Falha de regra de negócio executada depois da validação pelo XSD.
 */
public final class PedidoImportValidationException
        extends XmlImportException {
    private static final long serialVersionUID = 1L;

    public PedidoImportValidationException(String message) {
        super(message);
    }
}
