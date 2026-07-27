package br.com.asillos.migration.persistence;

import java.util.List;

import br.com.asillos.migration.domain.Anexo;

import org.apache.ibatis.annotations.Param;

/**
 * Contrato Java do mapper XML de anexos.
 */
public interface AnexoMapper {
    Long proximoId();

    List<Anexo> listarPorPedido(@Param("pedidoId") Long pedidoId);

    Anexo buscarPorId(@Param("id") Long id);

    int inserir(Anexo anexo);
}
