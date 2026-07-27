package br.com.asillos.migration.domain;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.Date;

/**
 * Pedido mínimo preservado durante todas as fases do laboratório.
 */
public class Pedido implements Serializable {
    private static final long serialVersionUID = 1L;

    private Long id;
    private String numero;
    private String clienteNome;
    private String descricao;
    private BigDecimal valorTotal;
    private StatusPedido status;
    private Date criadoEm;
    private Date atualizadoEm;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getNumero() {
        return numero;
    }

    public void setNumero(String numero) {
        this.numero = numero;
    }

    public String getClienteNome() {
        return clienteNome;
    }

    public void setClienteNome(String clienteNome) {
        this.clienteNome = clienteNome;
    }

    public String getDescricao() {
        return descricao;
    }

    public void setDescricao(String descricao) {
        this.descricao = descricao;
    }

    public BigDecimal getValorTotal() {
        return valorTotal;
    }

    public void setValorTotal(BigDecimal valorTotal) {
        this.valorTotal = valorTotal;
    }

    public StatusPedido getStatus() {
        return status;
    }

    public void setStatus(StatusPedido status) {
        this.status = status;
    }

    public Date getCriadoEm() {
        return copy(criadoEm);
    }

    public void setCriadoEm(Date criadoEm) {
        this.criadoEm = copy(criadoEm);
    }

    public Date getAtualizadoEm() {
        return copy(atualizadoEm);
    }

    public void setAtualizadoEm(Date atualizadoEm) {
        this.atualizadoEm = copy(atualizadoEm);
    }

    private static Date copy(Date value) {
        return value == null ? null : new Date(value.getTime());
    }
}
