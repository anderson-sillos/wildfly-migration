package br.com.asillos.migration.persistence;

import java.math.BigDecimal;
import java.util.Date;
import java.util.List;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.domain.StatusPedido;

import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Operações de pedido com validação mínima e limite transacional explícito.
 */
public final class PedidoRepository {
    private static final Logger MAPPER_LOGGER =
            LoggerFactory.getLogger(PedidoMapper.class);
    private final MyBatisTransactionTemplate transactions;

    public PedidoRepository(SqlSessionFactory sessionFactory) {
        transactions = new MyBatisTransactionTemplate(sessionFactory);
    }

    public List<Pedido> listar() {
        return transactions.execute(new TransactionWork<List<Pedido>>() {
            @Override
            public List<Pedido> execute(SqlSession session) {
                MAPPER_LOGGER.info("mybatis_mapper=PedidoMapper operation=listar");
                return session.getMapper(PedidoMapper.class).listar();
            }
        });
    }

    public Pedido buscarPorId(final Long id) {
        if (id == null) {
            throw new IllegalArgumentException("ID do pedido é obrigatório");
        }
        return transactions.execute(new TransactionWork<Pedido>() {
            @Override
            public Pedido execute(SqlSession session) {
                MAPPER_LOGGER.info("mybatis_mapper=PedidoMapper operation=buscarPorId");
                return session.getMapper(PedidoMapper.class).buscarPorId(id);
            }
        });
    }

    public Pedido criar(final Pedido pedido) {
        if (pedido != null) {
            pedido.setStatus(StatusPedido.NOVO);
        }
        return persistirNovo(pedido);
    }

    /**
     * Persiste um pedido já validado pelo contrato de importação.
     */
    public Pedido importar(final Pedido pedido) {
        if (pedido == null || pedido.getStatus() == null) {
            throw new IllegalArgumentException(
                    "Status do pedido importado é obrigatório");
        }
        return persistirNovo(pedido);
    }

    private Pedido persistirNovo(final Pedido pedido) {
        validateNewPedido(pedido);
        return transactions.execute(new TransactionWork<Pedido>() {
            @Override
            public Pedido execute(SqlSession session) {
                PedidoMapper mapper = session.getMapper(PedidoMapper.class);
                MAPPER_LOGGER.info("mybatis_mapper=PedidoMapper operation=criar");
                Date now = new Date();
                pedido.setId(mapper.proximoId());
                pedido.setCriadoEm(now);
                pedido.setAtualizadoEm(now);
                int affectedRows = mapper.inserir(pedido);
                if (affectedRows != 1) {
                    throw new IllegalStateException(
                            "Inclusão do pedido não afetou exatamente uma linha");
                }
                return mapper.buscarPorId(pedido.getId());
            }
        });
    }

    private void validateNewPedido(Pedido pedido) {
        if (pedido == null) {
            throw new IllegalArgumentException("Pedido é obrigatório");
        }
        if (pedido.getId() != null) {
            throw new IllegalArgumentException(
                    "ID do pedido é definido pelo servidor");
        }
        pedido.setNumero(required(
                "Número", pedido.getNumero(), 32));
        pedido.setClienteNome(required(
                "Nome do cliente", pedido.getClienteNome(), 120));
        pedido.setDescricao(optional(
                "Descrição", pedido.getDescricao(), 500));

        BigDecimal value = pedido.getValorTotal();
        if (value == null || value.signum() < 0 || value.scale() > 2
                || value.precision() - value.scale() > 13) {
            throw new IllegalArgumentException(
                    "Valor total deve ser positivo e respeitar NUMBER(15,2)");
        }
    }

    private String required(String field, String value, int maximum) {
        String normalized = optional(field, value, maximum);
        if (normalized == null || normalized.length() == 0) {
            throw new IllegalArgumentException(field + " é obrigatório");
        }
        return normalized;
    }

    private String optional(String field, String value, int maximum) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        if (normalized.length() > maximum) {
            throw new IllegalArgumentException(
                    field + " excede " + maximum + " caracteres");
        }
        return normalized;
    }
}
