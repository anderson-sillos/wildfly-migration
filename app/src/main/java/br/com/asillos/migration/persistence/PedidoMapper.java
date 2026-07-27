package br.com.asillos.migration.persistence;

import java.util.List;

import br.com.asillos.migration.domain.Pedido;

import org.apache.ibatis.annotations.Param;

/**
 * Contrato Java do mapper XML de pedidos.
 */
public interface PedidoMapper {
    Long proximoId();

    List<Pedido> listar();

    Pedido buscarPorId(@Param("id") Long id);

    Pedido buscarPorNumero(@Param("numero") String numero);

    int inserir(Pedido pedido);

    int atualizar(Pedido pedido);
}
