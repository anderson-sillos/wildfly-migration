package br.com.asillos.migration.integration.validation;

import br.com.asillos.migration.domain.Pedido;

/**
 * Extensão legada descoberta em runtime pelo Reflections.
 */
public interface PedidoImportValidator {
    int order();

    String identifier();

    void validate(Pedido pedido)
            throws PedidoImportValidationException;
}
