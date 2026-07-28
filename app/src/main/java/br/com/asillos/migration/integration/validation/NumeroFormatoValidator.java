package br.com.asillos.migration.integration.validation;

import java.util.regex.Pattern;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.integration.xml.XmlImportException;

/**
 * Confirma a regra de número já expressa pelo XSD.
 */
public final class NumeroFormatoValidator
        implements PedidoImportValidator {
    private static final Pattern FORMAT =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._-]*");

    @Override
    public int order() {
        return 10;
    }

    @Override
    public String identifier() {
        return "numero-formato";
    }

    @Override
    public void validate(Pedido pedido) throws XmlImportException {
        String numero = pedido == null ? null : pedido.getNumero();
        if (numero == null || !FORMAT.matcher(numero).matches()) {
            throw new XmlImportException(
                    "Pedido importado tem número fora do contrato");
        }
    }
}
