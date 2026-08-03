package br.com.asillos.migration.web;

import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.List;

import jakarta.servlet.http.HttpServletRequest;

import org.apache.commons.fileupload.FileUploadException;
import org.apache.commons.fileupload.RequestContext;
import org.apache.commons.fileupload.servlet.ServletFileUpload;

/**
 * Adapta uma requisição Jakarta para a API temporária do FileUpload 1.x.
 *
 * <p>A biblioteca mantida no gate ainda declara sobrecargas javax.servlet.
 * O adaptador mantém o código web em Jakarta até a substituição nativa por
 * {@code Part} na atividade 3.32.</p>
 */
final class JakartaFileUploadRequestContext implements RequestContext {

    private final HttpServletRequest request;

    JakartaFileUploadRequestContext(HttpServletRequest request) {
        this.request = request;
    }

    static boolean isMultipartContent(HttpServletRequest request) {
        String contentType = request.getContentType();
        return contentType != null
                && contentType.regionMatches(
                        true, 0, "multipart/", 0, "multipart/".length());
    }

    /**
     * Invoca a sobrecarga RequestContext sem resolver a assinatura javax do
     * FileUpload no bytecode da aplicação Jakarta.
     */
    static List<?> parseRequest(
            ServletFileUpload upload,
            HttpServletRequest request) throws FileUploadException {
        try {
            Class<?> base = Class.forName(
                    "org.apache.commons.fileupload.FileUploadBase");
            Method method = base.getMethod(
                    "parseRequest", RequestContext.class);
            return (List<?>) method.invoke(
                    upload, new JakartaFileUploadRequestContext(request));
        } catch (InvocationTargetException exception) {
            Throwable cause = exception.getCause();
            if (cause instanceof FileUploadException) {
                throw (FileUploadException) cause;
            }
            if (cause instanceof RuntimeException) {
                throw (RuntimeException) cause;
            }
            throw new FileUploadException(
                    "Falha ao interpretar requisição multipart", cause);
        } catch (ReflectiveOperationException exception) {
            throw new FileUploadException(
                    "A API RequestContext do FileUpload não está disponível",
                    exception);
        }
    }

    @Override
    public String getCharacterEncoding() {
        return request.getCharacterEncoding();
    }

    @Override
    public int getContentLength() {
        return request.getContentLength();
    }

    @Override
    public String getContentType() {
        return request.getContentType();
    }

    @Override
    public InputStream getInputStream() throws IOException {
        return request.getInputStream();
    }
}
