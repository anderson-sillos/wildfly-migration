package br.com.asillos.migration.web;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collection;

import jakarta.servlet.RequestDispatcher;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;

import br.com.asillos.migration.domain.Pedido;
import br.com.asillos.migration.integration.validation.PedidoImportValidationException;
import br.com.asillos.migration.integration.xml.LegacyPedidoXmlParser;
import br.com.asillos.migration.integration.xml.XmlImportException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
/**
 * Endpoint HTTP de importação XML com limite explícito.
 */
@MultipartConfig(
        fileSizeThreshold = XmlImportServlet.MEMORY_THRESHOLD_BYTES,
        maxFileSize = XmlImportServlet.MAX_XML_BYTES,
        maxRequestSize = XmlImportServlet.MAX_MULTIPART_REQUEST_BYTES)
public final class XmlImportServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    private static final Logger LOGGER =
            LoggerFactory.getLogger(XmlImportServlet.class);

    public static final int MAX_XML_BYTES = 128 * 1024;
    public static final long MAX_MULTIPART_REQUEST_BYTES = 160L * 1024L;
    public static final int MEMORY_THRESHOLD_BYTES = 32 * 1024;

    private static final int STATUS_REQUEST_TOO_LARGE = 413;
    private static final String FILE_FIELD = "arquivoXml";
    private static final String XSD_RESOURCE =
            "/WEB-INF/classes/xsd/pedido-importacao-v1.xsd";
    private static final String ERROR_VIEW = "/WEB-INF/views/erro.jsp";
    private static final String FORM_VIEW =
            "/WEB-INF/views/pedidos/importacao-xml.jsp";

    private transient LegacyPedidoXmlParser parser;

    @Override
    public void init() throws ServletException {
        try {
            parser = new LegacyPedidoXmlParser(
                    getServletContext().getResourceAsStream(XSD_RESOURCE),
                    getServletContext());
        } catch (XmlImportException exception) {
            throw new ServletException(
                    "Falha ao inicializar contrato XML", exception);
        }
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        request.setAttribute(
                SessionPreferences.ATTRIBUTE,
                SessionPreferences.get(request.getSession(true)));
        getServletContext().getRequestDispatcher(FORM_VIEW)
                .forward(request, response);
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response) throws ServletException, IOException {
        boolean multipart = MultipartPartSupport.isMultipartContent(request);
        if (!multipart && !isXmlContentType(request.getContentType())) {
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_UNSUPPORTED_MEDIA_TYPE,
                    "Use Content-Type application/xml ou text/xml");
            return;
        }
        if (!multipart && request.getContentLength() > MAX_XML_BYTES) {
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O XML excede o limite de 128 KiB");
            return;
        }

        try {
            LOGGER.info("legacy_xml_import started");
            byte[] xml = multipart
                    ? readMultipart(request)
                    : readBounded(request.getInputStream());
            Pedido pedido = parser.parse(xml);
            Pedido imported =
                    ApplicationResources.pedidoRepository(getServletContext())
                            .importar(pedido);
            LOGGER.info("legacy_xml_import accepted");
            response.sendRedirect(response.encodeRedirectURL(
                    request.getContextPath()
                    + "/pedidos/detalhe?id="
                    + imported.getId()
                    + "&importacao=ok"));
        } catch (RequestTooLargeException exception) {
            LOGGER.warn("legacy_xml_import rejected reason=size");
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O XML excede o limite de 128 KiB");
        } catch (MultipartPartSupport.SizeLimitException exception) {
            LOGGER.warn("legacy_xml_import rejected reason=size");
            safeError(
                    request,
                    response,
                    STATUS_REQUEST_TOO_LARGE,
                    "O XML excede o limite de 128 KiB");
        } catch (ServletException exception) {
            LOGGER.warn("legacy_xml_import rejected reason=multipart");
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Não foi possível interpretar o arquivo XML enviado");
        } catch (PedidoImportValidationException exception) {
            LOGGER.warn(
                    "legacy_xml_import rejected reason=domain_validator");
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (XmlImportException exception) {
            LOGGER.warn("legacy_xml_import rejected reason=xml_contract");
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (IllegalArgumentException exception) {
            LOGGER.warn("legacy_xml_import rejected reason=domain_contract");
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_BAD_REQUEST,
                    exception.getMessage());
        } catch (RuntimeException exception) {
            LOGGER.error(
                    "legacy_xml_import persistence_failure",
                    exception);
            safeError(
                    request,
                    response,
                    HttpServletResponse.SC_SERVICE_UNAVAILABLE,
                    "Não foi possível persistir o pedido importado");
        }
    }

    private byte[] readMultipart(HttpServletRequest request)
            throws IOException, ServletException,
            MultipartPartSupport.SizeLimitException {
        Collection<Part> parsedParts = MultipartPartSupport.parse(request);
        try {
            Part xmlPart = null;
            for (Part part : parsedParts) {
                if (!FILE_FIELD.equals(part.getName())
                        || part.getSubmittedFileName() == null
                        || xmlPart != null) {
                    throw new IllegalArgumentException(
                            "Selecione somente um arquivo XML");
                }
                xmlPart = part;
            }
            if (xmlPart == null || xmlPart.getSize() == 0L) {
                throw new IllegalArgumentException(
                        "Selecione um arquivo XML não vazio");
            }
            return MultipartPartSupport.read(xmlPart, MAX_XML_BYTES);
        } finally {
            for (Part part : parsedParts) {
                try {
                    part.delete();
                } catch (IOException exception) {
                    LOGGER.warn(
                            "legacy_xml_import temporary_cleanup_failure",
                            exception);
                }
            }
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
