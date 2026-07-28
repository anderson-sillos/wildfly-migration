package br.com.asillos.migration.integration.validation;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.integration.xml.XmlImportException;

/**
 * Extensão legada descoberta em runtime pelo Reflections.
 */
public interface PedidoImportValidator {
    int order();

    String identifier();

    void validate(Pedido pedido) throws XmlImportException;
}
