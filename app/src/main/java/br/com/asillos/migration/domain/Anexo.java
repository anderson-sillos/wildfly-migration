package br.com.asillos.migration.domain;

import java.io.Serializable;
import java.util.Date;

/**
 * Metadados e conteúdo binário associados a um pedido.
 */
public class Anexo implements Serializable {
    private static final long serialVersionUID = 1L;

    private Long id;
    private Long pedidoId;
    private String nomeArquivo;
    private String tipoConteudo;
    private Long tamanhoBytes;
    private String sha256;
    private byte[] conteudo;
    private Date criadoEm;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getPedidoId() {
        return pedidoId;
    }

    public void setPedidoId(Long pedidoId) {
        this.pedidoId = pedidoId;
    }

    public String getNomeArquivo() {
        return nomeArquivo;
    }

    public void setNomeArquivo(String nomeArquivo) {
        this.nomeArquivo = nomeArquivo;
    }

    public String getTipoConteudo() {
        return tipoConteudo;
    }

    public void setTipoConteudo(String tipoConteudo) {
        this.tipoConteudo = tipoConteudo;
    }

    public Long getTamanhoBytes() {
        return tamanhoBytes;
    }

    public void setTamanhoBytes(Long tamanhoBytes) {
        this.tamanhoBytes = tamanhoBytes;
    }

    public String getSha256() {
        return sha256;
    }

    public void setSha256(String sha256) {
        this.sha256 = sha256;
    }

    public byte[] getConteudo() {
        return copy(conteudo);
    }

    public void setConteudo(byte[] conteudo) {
        this.conteudo = copy(conteudo);
    }

    public Date getCriadoEm() {
        return criadoEm == null ? null : new Date(criadoEm.getTime());
    }

    public void setCriadoEm(Date criadoEm) {
        this.criadoEm =
                criadoEm == null ? null : new Date(criadoEm.getTime());
    }

    private static byte[] copy(byte[] value) {
        if (value == null) {
            return null;
        }
        byte[] result = new byte[value.length];
        System.arraycopy(value, 0, result, 0, value.length);
        return result;
    }
}
