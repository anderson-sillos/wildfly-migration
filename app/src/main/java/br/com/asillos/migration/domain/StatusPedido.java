package br.com.asillos.migration.domain;

/**
 * Estados persistidos no contrato do pedido.
 */
public enum StatusPedido {
    NOVO,
    APROVADO,
    CANCELADO;

    public static StatusPedido fromDatabaseValue(String value) {
        if (value == null) {
            return null;
        }
        return valueOf(value.trim());
    }
}
