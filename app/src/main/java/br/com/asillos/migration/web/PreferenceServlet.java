package br.com.asillos.migration.web;

import java.io.IOException;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Atualiza exclusivamente a preferência armazenada em HttpSession.
 */
public final class PreferenceServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response) throws IOException {
        SessionPreferences.set(
                request.getSession(true),
                request.getParameter("modoExibicao"));
        response.sendRedirect(
                response.encodeRedirectURL(
                        request.getContextPath() + "/pedidos"));
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response) throws IOException, ServletException {
        response.sendError(HttpServletResponse.SC_METHOD_NOT_ALLOWED);
    }
}
