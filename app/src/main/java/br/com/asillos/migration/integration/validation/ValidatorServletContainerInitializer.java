package br.com.asillos.migration.integration.validation;

import java.util.Set;

import jakarta.servlet.ServletContainerInitializer;
import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.HandlesTypes;

/**
 * Entrada padrão Servlet para descoberta de validadores anotados.
 */
@HandlesTypes(Validator.class)
public final class ValidatorServletContainerInitializer
        implements ServletContainerInitializer {

    @Override
    public void onStartup(
            Set<Class<?>> classes,
            ServletContext context) throws ServletException {
        ValidatorDiscovery.initialize(context, classes);
    }
}
