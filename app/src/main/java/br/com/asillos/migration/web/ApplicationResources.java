package br.com.asillos.migration.web;

import javax.servlet.ServletContext;

import br.com.asillos.migration.persistence.AnexoRepository;
import br.com.asillos.migration.persistence.PedidoRepository;

/**
 * Chaves e acesso tipado aos recursos inicializados pela aplicação.
 */
public final class ApplicationResources {
    public static final String PEDIDO_REPOSITORY =
            PedidoRepository.class.getName();
    public static final String ANEXO_REPOSITORY =
            AnexoRepository.class.getName();
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

    public static AnexoRepository anexoRepository(ServletContext context) {
        Object value = context.getAttribute(ANEXO_REPOSITORY);
        if (!(value instanceof AnexoRepository)) {
            throw new IllegalStateException(
                    "Repositório de anexos não foi inicializado");
        }
        return (AnexoRepository) value;
    }
}
