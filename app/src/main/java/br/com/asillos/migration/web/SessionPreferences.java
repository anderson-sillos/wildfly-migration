package br.com.asillos.migration.web;

import jakarta.servlet.http.HttpSession;

/**
 * Contrato estável da preferência que vive somente na sessão HTTP.
 */
public final class SessionPreferences {
    public static final String ATTRIBUTE = "modoExibicao";
    public static final String COMPACTO = "COMPACTO";
    public static final String DETALHADO = "DETALHADO";

    private SessionPreferences() {
    }

    public static String get(HttpSession session) {
        Object value = session.getAttribute(ATTRIBUTE);
        String normalized = normalize(value == null ? null : value.toString());
        session.setAttribute(ATTRIBUTE, normalized);
        return normalized;
    }

    public static String set(HttpSession session, String value) {
        String normalized = normalize(value);
        session.setAttribute(ATTRIBUTE, normalized);
        return normalized;
    }

    private static String normalize(String value) {
        return COMPACTO.equals(value) ? COMPACTO : DETALHADO;
    }
}
