package br.com.asillos.migration.web;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.integration.xml.LegacyPedidoXmlParser;
import br.com.asillos.migration.integration.xml.XmlImportException;

/**
 * Endpoint HTTP de importação XML com limite explícito.
 */
public final class XmlImportServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    public static final int MAX_XML_BYTES = 128 * 1024;

    private static final int STATUS_REQUEST_TOO_LARGE = 413;
    private static final String XSD_RESOURCE =
            "/WEB-INF/classes/xsd/pedido-importacao-v1.xsd";
    private static final String ERROR_VIEW = "/WEB-INF/views/erro.jsp";

    private LegacyPedidoXmlParser parser;

    @Override
    public void init() throws ServletException {
        try {
            parser = new LegacyPedidoXmlParser(
                    getServletContext().getResourceAsStream(XSD_RESOURCE));
        } catch (XmlImportException exception) {
            throw new ServletException(
                    "Falha ao inicializar contrato XML", exception);
        }
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        response.setHeader("Allow", "POST");
        safeError(
                request,
                response,
                HttpServletResponse.SC_METHOD_NOT_ALLOWED,
                "A importação XML aceita somente requisições POST");
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        if (!isXmlContentType(request.getContentType())) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_UNSUPPORTED_MEDIA_TYPE,
                    "Use Content-Type application/xml ou text/xml");
            return;
        }
        if (request.getContentLength() > MAX_XML_BYTES) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O XML excede o limite de 128 KiB");
            return;
        }

        try {
            byte[] xml = readBounded(request.getInputStream());
            Pedido pedido = parser.parse(xml);
            Pedido imported =
                    ApplicationResources.pedidoRepository(getServletContext())
                            .importar(pedido);
            response.sendRedirect(response.encodeRedirectURL(
                    request.getContextPath()
                    + "/pedidos/detalhe?id="
                    + imported.getId()
                    + "&importacao=ok"));
        } catch (RequestTooLargeException exception) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O XML excede o limite de 128 KiB");
        } catch (XmlImportException exception) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (IllegalArgumentException exception) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (RuntimeException exception) {
            getServletContext().log(
                    "Falha controlada na importação XML; correlação="
                    + correlation(request));
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Não foi possível persistir o pedido importado");
        }
    }

    private byte[] readBounded(InputStream input)
            throws IOException, RequestTooLargeException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int count;
        while ((count = input.read(buffer)) >= 0) {
            if (output.size() + count > MAX_XML_BYTES) {
                throw new RequestTooLargeException();
            }
            output.write(buffer, 0, count);
        }
        return output.toByteArray();
    }

    private boolean isXmlContentType(String contentType) {
        if (contentType == null) {
            return false;
        }
        String normalized = contentType.toLowerCase();
        return normalized.equals("application/xml")
                || normalized.startsWith("application/xml;")
                || normalized.equals("text/xml")
                || normalized.startsWith("text/xml;");
    }

    private void safeError(
            HttpServletRequest request,
            HttpServletResponse response,
            int status,
            String message) throws ServletException, IOException {
        response.setStatus(status);
        request.setAttribute("mensagemErro", message);
        request.setAttribute("correlationId", correlation(request));
        request.setAttribute(
                SessionPreferences.ATTRIBUTE,
                SessionPreferences.get(request.getSession(true)));
        RequestDispatcher dispatcher =
                getServletContext().getRequestDispatcher(ERROR_VIEW);
        dispatcher.forward(request, response);
    }

    private String correlation(HttpServletRequest request) {
        Object value = request.getAttribute(
                RequestContextFilter.CORRELATION_ATTRIBUTE);
        return value == null ? "indisponível" : value.toString();
    }

    private static final class RequestTooLargeException extends Exception {
        private static final long serialVersionUID = 1L;
    }
}
