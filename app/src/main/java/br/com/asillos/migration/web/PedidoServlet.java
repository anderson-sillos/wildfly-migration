package br.com.asillos.migration.web;

import java.io.IOException;
import java.math.BigDecimal;
import java.util.List;

import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.persistence.PedidoRepository;

/**
 * Endpoints de listagem, formulário, criação e detalhe de pedidos.
 */
public final class PedidoServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private static final String LIST_VIEW =
            "/WEB-INF/views/pedidos/lista.jsp";
    private static final String FORM_VIEW =
            "/WEB-INF/views/pedidos/formulario.jsp";
    private static final String DETAIL_VIEW =
            "/WEB-INF/views/pedidos/detalhe.jsp";
    private static final String ERROR_VIEW =
            "/WEB-INF/views/erro.jsp";

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws IOException, ServletException {
        String path = request.getPathInfo();
        if (path == null || "/".equals(path)) {
            list(request, response);
        } else if ("/novo".equals(path)) {
            showForm(request, response);
        } else if ("/detalhe".equals(path)) {
            detail(request, response);
        } else {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_NOT_FOUND,
                    "Recurso de pedido não encontrado");
        }
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response) throws IOException, ServletException {
        String path = request.getPathInfo();
        if (path == null || "/".equals(path)) {
            create(request, response);
        } else {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_METHOD_NOT_ALLOWED,
                    "Operação de pedido não permitida");
        }
    }

    private void list(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        try {
            List<Pedido> pedidos = repository().listar();
            request.setAttribute("pedidos", pedidos);
            exposePreference(request);
            forward(request, response, LIST_VIEW);
        } catch (RuntimeException exception) {
            persistenceFailure(request, response);
        }
    }

    private void showForm(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        exposePreference(request);
        forward(request, response, FORM_VIEW);
    }

    private void detail(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        Long id = positiveLong(request.getParameter("id"));
        if (id == null) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Identificador de pedido inválido");
            return;
        }

        try {
            Pedido pedido = repository().buscarPorId(id);
            if (pedido == null) {
                safeError(
                        request,
                        response,
                        HttpServletResponse.SC_NOT_FOUND,
                        "Pedido não encontrado");
                return;
            }
            request.setAttribute("pedido", pedido);
            exposePreference(request);
            forward(request, response, DETAIL_VIEW);
        } catch (RuntimeException exception) {
            persistenceFailure(request, response);
        }
    }

    private void create(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        Pedido pedido = new Pedido();
        pedido.setNumero(request.getParameter("numero"));
        pedido.setClienteNome(request.getParameter("clienteNome"));
        pedido.setDescricao(request.getParameter("descricao"));

        try {
            String value = request.getParameter("valorTotal");
            pedido.setValorTotal(
                    value == null ? null : new BigDecimal(value.trim()));
            Pedido created = repository().criar(pedido);
            response.sendRedirect(
                    response.encodeRedirectURL(
                            request.getContextPath()
                            + "/pedidos/detalhe?id="
                            + created.getId()));
        } catch (NumberFormatException exception) {
            invalidForm(
                    request,
                    response,
                    pedido,
                    "Valor total deve ser um número decimal");
        } catch (IllegalArgumentException exception) {
            invalidForm(
                    request,
                    response,
                    pedido,
                    exception.getMessage());
        } catch (RuntimeException exception) {
            persistenceFailure(request, response);
        }
    }

    private void invalidForm(
            HttpServletRequest request,
            HttpServletResponse response,
            Pedido pedido,
            String message) throws ServletException, IOException {
        response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
        request.setAttribute("pedido", pedido);
        request.setAttribute("mensagemErro", message);
        exposePreference(request);
        forward(request, response, FORM_VIEW);
    }

    private void persistenceFailure(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        getServletContext().log(
                "Falha controlada de persistência; correlação="
                + correlation(request));
        safeError(
                request,
                response,
                HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                "Persistência temporariamente indisponível");
    }

    private void safeError(
            HttpServletRequest request,
            HttpServletResponse response,
            int status,
            String message) throws ServletException, IOException {
        response.setStatus(status);
        request.setAttribute("mensagemErro", message);
        request.setAttribute("correlationId", correlation(request));
        exposePreference(request);
        forward(request, response, ERROR_VIEW);
    }

    private void exposePreference(HttpServletRequest request) {
        request.setAttribute(
                SessionPreferences.ATTRIBUTE,
                SessionPreferences.get(request.getSession(true)));
    }

    private String correlation(HttpServletRequest request) {
        Object value = request.getAttribute(
                RequestContextFilter.CORRELATION_ATTRIBUTE);
        return value == null ? "indisponível" : value.toString();
    }

    private PedidoRepository repository() {
        return ApplicationResources.pedidoRepository(getServletContext());
    }

    private void forward(
            HttpServletRequest request,
            HttpServletResponse response,
            String view) throws ServletException, IOException {
        RequestDispatcher dispatcher =
                getServletContext().getRequestDispatcher(view);
        dispatcher.forward(request, response);
    }

    private Long positiveLong(String value) {
        if (value == null) {
            return null;
        }
        try {
            Long parsed = Long.valueOf(value);
            return parsed.longValue() > 0L ? parsed : null;
        } catch (NumberFormatException exception) {
            return null;
        }
    }
}
