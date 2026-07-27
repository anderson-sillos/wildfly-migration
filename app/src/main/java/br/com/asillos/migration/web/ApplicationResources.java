package br.com.asillos.migration.web;

import javax.servlet.ServletContext;

import br.com.asillos.migration.persistence.PedidoRepository;

/**
 * Chaves e acesso tipado aos recursos inicializados pela aplicação.
 */
public final class ApplicationResources {
    public static final String PEDIDO_REPOSITORY =
            PedidoRepository.class.getName();
    public static final String STARTED_AT =
            ApplicationResources.class.getName() + ".startedAt";

    private ApplicationResources() {
    }

    public static PedidoRepository pedidoRepository(ServletContext context) {
        Object value = context.getAttribute(PEDIDO_REPOSITORY);
        if (!(value instanceof PedidoRepository)) {
            throw new IllegalStateException(
                    "Repositório de pedidos não foi inicializado");
        }
        return (PedidoRepository) value;
    }
}
