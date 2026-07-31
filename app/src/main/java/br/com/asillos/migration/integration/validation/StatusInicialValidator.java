package br.com.asillos.migration.integration.validation;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;

/**
 * Impede que uma importação ignore o estado inicial do fluxo de negócio.
 */
@Validator
public final class StatusInicialValidator
        implements PedidoImportValidator {
    @Override
    public int order() {
        return 30;
    }

    @Override
    public String identifier() {
        return "status-inicial";
    }

    @Override
    public void validate(Pedido pedido)
            throws PedidoImportValidationException {
        StatusPedido status =
                pedido == null ? null : pedido.getStatus();
        if (status != StatusPedido.NOVO) {
            throw new PedidoImportValidationException(
                    "Pedido importado deve iniciar com status NOVO");
        }
    }
}
