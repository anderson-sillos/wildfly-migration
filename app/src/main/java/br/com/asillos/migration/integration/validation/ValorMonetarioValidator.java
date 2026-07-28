package br.com.asillos.migration.integration.validation;

import java.math.BigDecimal;

import br.com.asillos.migration.domain.Pedido;

/**
 * Confirma a semântica monetária comum ao XSD e aos dois bancos.
 */
public final class ValorMonetarioValidator
        implements PedidoImportValidator {
    @Override
    public int order() {
        return 20;
    }

    @Override
    public String identifier() {
        return "valor-monetario";
    }

    @Override
    public void validate(Pedido pedido)
            throws PedidoImportValidationException {
        BigDecimal value =
                pedido == null ? null : pedido.getValorTotal();
        if (value == null || value.signum() < 0 || value.scale() > 2
                || value.precision() - value.scale() > 13) {
            throw new PedidoImportValidationException(
                    "Pedido importado tem valor fora do contrato");
        }
    }
}
