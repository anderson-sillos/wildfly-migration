package br.com.asillos.migration.web;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;

import br.com.asillos.migration.persistence.AnexoRepository;

import org.apache.log4j.Logger;

/**
 * Upload multipart usando a API nativa do Servlet/Jakarta.
 */
@MultipartConfig(
        fileSizeThreshold = UploadServlet.MEMORY_THRESHOLD_BYTES,
        maxFileSize = AnexoRepository.MAX_FILE_BYTES,
        maxRequestSize = UploadServlet.MAX_REQUEST_BYTES)
public final class UploadServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private static final Logger LOGGER =
            Logger.getLogger(UploadServlet.class);

    public static final long MAX_REQUEST_BYTES = 576L * 1024L;
    public static final int MEMORY_THRESHOLD_BYTES = 32 * 1024;

    private static final int STATUS_REQUEST_TOO_LARGE = 413;
    private static final String FILE_FIELD = "arquivo";
    private static final String ERROR_VIEW = "/WEB-INF/views/erro.jsp";

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        response.setHeader("Allow", "POST");
        safeError(
                request,
                response,
                HttpServletResponse.SC_METHOD_NOT_ALLOWED,
                "O upload aceita somente requisições POST");
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        if (!MultipartPartSupport.isMultipartContent(request)) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Envie o anexo como multipart/form-data");
            return;
        }

        Long pedidoId = positiveLong(request.getParameter("pedidoId"));
        if (pedidoId == null) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Identificador do pedido é inválido");
            return;
        }

        List<Part> parsedParts = new ArrayList<Part>();
        try {
            Collection<Part> parts = MultipartPartSupport.parse(request);
            Part filePart = null;
            for (Part part : parts) {
                parsedParts.add(part);
                if (!FILE_FIELD.equals(part.getName())
                        || part.getSubmittedFileName() == null
                        || filePart != null) {
                    throw new IllegalArgumentException(
                            "O upload deve conter somente um arquivo");
                }
                filePart = part;
            }
            if (filePart == null || filePart.getSize() == 0L) {
                throw new IllegalArgumentException(
                        "Selecione um arquivo para anexar");
            }

            repository().criar(
                    pedidoId,
                    MultipartPartSupport.submittedFileName(filePart),
                    filePart.getContentType(),
                    MultipartPartSupport.read(
                            filePart, AnexoRepository.MAX_FILE_BYTES));
            response.sendRedirect(response.encodeRedirectURL(
                    request.getContextPath()
                    + "/pedidos/detalhe?id="
                    + pedidoId
                    + "&upload=ok"));
        } catch (MultipartPartSupport.SizeLimitException exception) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O arquivo excede o limite de 512 KiB");
        } catch (ServletException exception) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Não foi possível interpretar o formulário multipart");
        } catch (IllegalArgumentException exception) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (RuntimeException exception) {
            LOGGER.error("legacy_upload persistence_failure", exception);
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Não foi possível persistir o anexo");
        } finally {
            for (Part part : parsedParts) {
                try {
                    part.delete();
                } catch (IOException exception) {
                    LOGGER.warn(
                            "legacy_upload temporary_cleanup_failure",
                            exception);
                }
            }
        }
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

    private AnexoRepository repository() {
        return ApplicationResources.anexoRepository(getServletContext());
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
