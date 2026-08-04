package br.com.asillos.migration.web;

import java.io.IOException;
import java.io.PrintWriter;

import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Verifica inicialização, JNDI, MyBatis e uma consulta simples.
 */
public final class HealthServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws IOException {
        response.setContentType("text/plain; charset=UTF-8");
        response.setHeader("Cache-Control", "no-store");
        PrintWriter writer = response.getWriter();
        try {
            ApplicationResources.pedidoRepository(getServletContext())
                    .listar();
            response.setStatus(HttpServletResponse.SC_OK);
            writer.println("status=UP");
        } catch (RuntimeException exception) {
            response.setStatus(HttpServletResponse.SC_SERVICE_UNAVAILABLE);
            writer.println("status=DOWN");
        }
    }
}
