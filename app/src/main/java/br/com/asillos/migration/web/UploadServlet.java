package br.com.asillos.migration.web;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import br.com.asillos.migration.persistence.AnexoRepository;

import org.apache.commons.fileupload.FileItem;
import org.apache.commons.fileupload.FileUploadBase;
import org.apache.commons.fileupload.FileUploadException;
import org.apache.commons.fileupload.disk.DiskFileItemFactory;
import org.apache.commons.fileupload.servlet.ServletFileUpload;

/**
 * Upload multipart deliberadamente implementado com Commons FileUpload 1.2.2.
 */
public final class UploadServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

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
        if (!ServletFileUpload.isMultipartContent(request)) {
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

        List<FileItem> parsedItems = new ArrayList<FileItem>();
        try {
            File temporaryRepository = (File) getServletContext()
                    .getAttribute("javax.servlet.context.tempdir");
            if (temporaryRepository == null
                    || !temporaryRepository.isDirectory()) {
                throw new IllegalStateException(
                        "Diretório temporário do servlet está indisponível");
            }

            DiskFileItemFactory factory = new DiskFileItemFactory(
                    MEMORY_THRESHOLD_BYTES, temporaryRepository);
            ServletFileUpload upload = new ServletFileUpload(factory);
            upload.setHeaderEncoding("UTF-8");
            upload.setFileSizeMax(AnexoRepository.MAX_FILE_BYTES);
            upload.setSizeMax(MAX_REQUEST_BYTES);

            List<?> rawItems = upload.parseRequest(request);
            FileItem fileItem = null;
            for (Object value : rawItems) {
                if (!(value instanceof FileItem)) {
                    throw new IllegalArgumentException(
                            "Parte multipart desconhecida");
                }
                FileItem item = (FileItem) value;
                parsedItems.add(item);
                if (item.isFormField()
                        || !FILE_FIELD.equals(item.getFieldName())
                        || fileItem != null) {
                    throw new IllegalArgumentException(
                            "O upload deve conter somente um arquivo");
                }
                fileItem = item;
            }
            if (fileItem == null) {
                throw new IllegalArgumentException(
                        "Selecione um arquivo para anexar");
            }

            repository().criar(
                    pedidoId,
                    fileItem.getName(),
                    fileItem.getContentType(),
                    fileItem.get());
            response.sendRedirect(response.encodeRedirectURL(
                    request.getContextPath()
                    + "/pedidos/detalhe?id="
                    + pedidoId
                    + "&upload=ok"));
        } catch (FileUploadBase.FileSizeLimitExceededException exception) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O arquivo excede o limite de 512 KiB");
        } catch (FileUploadBase.SizeLimitExceededException exception) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "A requisição excede o limite de 576 KiB");
        } catch (FileUploadException exception) {
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
            getServletContext().log(
                    "Falha controlada no upload; correlação="
                    + correlation(request));
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Não foi possível persistir o anexo");
        } finally {
            for (FileItem item : parsedItems) {
                try {
                    item.delete();
                } catch (RuntimeException exception) {
                    getServletContext().log(
                            "Falha ao limpar item multipart temporário");
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
