package br.com.asillos.migration.web;

import java.io.IOException;
import java.util.UUID;
import java.util.regex.Pattern;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.log4j.MDC;

/**
 * Aplica UTF-8 e um identificador de correlação seguro a cada requisição.
 */
public final class RequestContextFilter implements Filter {
    public static final String CORRELATION_ATTRIBUTE =
            RequestContextFilter.class.getName() + ".correlationId";
    public static final String CORRELATION_HEADER = "X-Correlation-ID";

    private static final Pattern SAFE_CORRELATION =
            Pattern.compile("[A-Za-z0-9._-]{1,64}");

    @Override
    public void init(FilterConfig filterConfig) {
        // Não há configuração mutável.
    }

    @Override
    public void doFilter(
            ServletRequest servletRequest,
            ServletResponse servletResponse,
            FilterChain chain) throws IOException, ServletException {
        servletRequest.setCharacterEncoding("UTF-8");
        servletResponse.setCharacterEncoding("UTF-8");

        String correlationId = UUID.randomUUID().toString();
        if (servletRequest instanceof HttpServletRequest) {
            String supplied = ((HttpServletRequest) servletRequest)
                    .getHeader(CORRELATION_HEADER);
            if (supplied != null
                    && SAFE_CORRELATION.matcher(supplied).matches()) {
                correlationId = supplied;
            }
        }

        servletRequest.setAttribute(CORRELATION_ATTRIBUTE, correlationId);
        if (servletResponse instanceof HttpServletResponse) {
            ((HttpServletResponse) servletResponse).setHeader(
                    CORRELATION_HEADER, correlationId);
        }
        MDC.put("correlationId", correlationId);
        try {
            chain.doFilter(servletRequest, servletResponse);
        } finally {
            MDC.remove("correlationId");
        }
    }

    @Override
    public void destroy() {
        // Não há recursos a liberar.
    }
}
