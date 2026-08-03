package br.com.asillos.migration.web.tag;

import java.io.IOException;

import jakarta.servlet.jsp.JspException;
import jakarta.servlet.jsp.tagext.SimpleTagSupport;

import br.com.asillos.migration.domain.StatusPedido;

/**
 * TLD 2.0 legado para representar um status com marcação previsível.
 */
public final class StatusPedidoTag extends SimpleTagSupport {
    private StatusPedido status;

    public void setStatus(StatusPedido status) {
        this.status = status;
    }

    @Override
    public void doTag() throws JspException, IOException {
        String cssClass = "desconhecido";
        String label = "Indefinido";
        if (StatusPedido.NOVO.equals(status)) {
            cssClass = "novo";
            label = "Novo";
        } else if (StatusPedido.APROVADO.equals(status)) {
            cssClass = "aprovado";
            label = "Aprovado";
        } else if (StatusPedido.CANCELADO.equals(status)) {
            cssClass = "cancelado";
            label = "Cancelado";
        }
        getJspContext().getOut().write(
                "<span class=\"status status-" + cssClass + "\">"
                + label + "</span>");
    }
}
