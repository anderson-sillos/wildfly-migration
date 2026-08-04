package br.com.asillos.migration.integration.validation;

import br.com.asillos.migration.domain.Pedido;

/**
 * Extensão descoberta em runtime pelo ServletContainerInitializer.
 */
public interface PedidoImportValidator {
    int order();

    String identifier();

    void validate(Pedido pedido)
            throws PedidoImportValidationException;
}
