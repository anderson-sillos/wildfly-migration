package br.com.asillos.migration.web;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Collection;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.Part;

/**
 * Pequena fachada para o multipart nativo do Servlet.
 *
 * <p>Concentra os limites defensivos que antes ficavam espalhados no
 * Commons FileUpload e mantém a aplicação independente de bibliotecas de
 * parsing multipart.</p>
 */
final class MultipartPartSupport {
    private MultipartPartSupport() {
    }

    static boolean isMultipartContent(HttpServletRequest request) {
        String contentType = request.getContentType();
        return contentType != null
                && contentType.toLowerCase().startsWith("multipart/form-data");
    }

    static Collection<Part> parse(HttpServletRequest request)
            throws IOException, ServletException, SizeLimitException {
        try {
            return request.getParts();
        } catch (IllegalStateException exception) {
            // O contêiner usa IllegalStateException para maxRequestSize.
            throw new SizeLimitException();
        }
    }

    static byte[] read(Part part, long maxBytes)
            throws IOException, SizeLimitException {
        if (part.getSize() > maxBytes) {
            throw new SizeLimitException();
        }
        ByteArrayOutputStream output = new ByteArrayOutputStream(
                (int) Math.min(part.getSize(), Integer.MAX_VALUE));
        byte[] buffer = new byte[4096];
        try (InputStream input = part.getInputStream()) {
            int count;
            while ((count = input.read(buffer)) >= 0) {
                if ((long) output.size() + count > maxBytes) {
                    throw new SizeLimitException();
                }
                output.write(buffer, 0, count);
            }
        }
        return output.toByteArray();
    }

    static String submittedFileName(Part part) {
        String value = part.getSubmittedFileName();
        if (value == null) {
            return null;
        }
        String normalized = value.replace('\\', '/');
        int separator = normalized.lastIndexOf('/');
        if (separator >= 0) {
            normalized = normalized.substring(separator + 1);
        }
        return normalized.trim();
    }

    static final class SizeLimitException extends Exception {
        private static final long serialVersionUID = 1L;
    }
}
