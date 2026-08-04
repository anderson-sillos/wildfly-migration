package br.com.asillos.migration.integration.validation;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletException;

import br.com.asillos.migration.integration.xml.XmlImportException;

/**
 * Fachada do registro de validadores inicializado pelo SCI do WAR.
 */
public final class ValidatorDiscovery {
    public static final String CONTEXT_ATTRIBUTE =
            ValidatorDiscovery.class.getName() + ".registry";

    private ValidatorDiscovery() {
    }

    /**
     * Constrói e registra os validadores elegíveis fornecidos pelo contêiner.
     */
    public static void initialize(
            ServletContext context,
            Set<Class<?>> candidates) throws ServletException {
        if (context == null) {
            throw new ServletException(
                    "ServletContext ausente para descoberta de validadores");
        }
        List<PedidoImportValidator> validators = instantiate(candidates);
        try {
            validateContract(validators);
        } catch (XmlImportException exception) {
            throw new ServletException(
                    "Contrato dos validadores descobertos é inválido",
                    exception);
        }
        context.setAttribute(
                CONTEXT_ATTRIBUTE,
                Collections.unmodifiableList(validators));
        context.log(
                "validator_sci_discovery classloader="
                + context.getClass().getClassLoader().getClass().getName()
                + " set=" + describeTypes(validators)
                + " order=" + describe(validators));
    }

    /**
     * Obtém a lista imutável vinculada ao ServletContext deste WAR.
     */
    public static List<PedidoImportValidator> discover(
            ServletContext context) throws XmlImportException {
        if (context == null) {
            throw new XmlImportException(
                    "ServletContext ausente para descoberta de validadores");
        }
        Object value = context.getAttribute(CONTEXT_ATTRIBUTE);
        if (!(value instanceof List<?>)) {
            throw new XmlImportException(
                    "SCI de validadores não foi inicializado");
        }
        List<?> registered = (List<?>) value;
        List<PedidoImportValidator> validators =
                new ArrayList<PedidoImportValidator>();
        for (Object candidate : registered) {
            if (!(candidate instanceof PedidoImportValidator)) {
                throw new XmlImportException(
                        "Registro SCI contém tipo de validador inválido");
            }
            validators.add((PedidoImportValidator) candidate);
        }
        validateContract(validators);
        return Collections.unmodifiableList(validators);
    }

    public static String describe(
            List<PedidoImportValidator> validators) {
        StringBuilder description = new StringBuilder();
        for (PedidoImportValidator validator : validators) {
            if (description.length() > 0) {
                description.append(',');
            }
            description.append(validator.identifier());
        }
        return description.toString();
    }

    private static List<PedidoImportValidator> instantiate(
            Set<Class<?>> candidates) throws ServletException {
        List<PedidoImportValidator> validators =
                new ArrayList<PedidoImportValidator>();
        if (candidates == null) {
            candidates = Collections.emptySet();
        }
        try {
            for (Class<?> type : candidates) {
                if (!type.isAnnotationPresent(Validator.class)
                        || !PedidoImportValidator.class.isAssignableFrom(type)
                        || type.isInterface()
                        || Modifier.isAbstract(type.getModifiers())) {
                    continue;
                }
                validators.add(type.asSubclass(PedidoImportValidator.class)
                        .getDeclaredConstructor().newInstance());
            }
        } catch (InstantiationException exception) {
            throw new ServletException(
                    "Validador descoberto não pôde ser instanciado",
                    exception);
        } catch (IllegalAccessException exception) {
            throw new ServletException(
                    "Validador descoberto não é acessível", exception);
        } catch (NoSuchMethodException exception) {
            throw new ServletException(
                    "Validador descoberto não possui construtor padrão",
                    exception);
        } catch (InvocationTargetException exception) {
            throw new ServletException(
                    "Construtor do validador descoberto falhou", exception);
        }

        Collections.sort(
                validators,
                new Comparator<PedidoImportValidator>() {
                    @Override
                    public int compare(
                            PedidoImportValidator left,
                            PedidoImportValidator right) {
                        int orderComparison =
                                left.order() < right.order() ? -1
                                : left.order() == right.order() ? 0 : 1;
                        if (orderComparison != 0) {
                            return orderComparison;
                        }
                        return left.getClass().getName().compareTo(
                                right.getClass().getName());
                    }
                });
        return validators;
    }

    private static String describeTypes(
            List<PedidoImportValidator> validators) {
        List<String> names = new ArrayList<String>();
        for (PedidoImportValidator validator : validators) {
            names.add(validator.getClass().getName());
        }
        Collections.sort(names);
        StringBuilder description = new StringBuilder();
        for (String name : names) {
            if (description.length() > 0) {
                description.append(',');
            }
            description.append(name);
        }
        return description.toString();
    }

    private static void validateContract(
            List<PedidoImportValidator> validators)
            throws XmlImportException {
        if (validators.isEmpty()) {
            throw new XmlImportException(
                    "Nenhum validador de importação foi descoberto");
        }
        Set<String> identifiers = new HashSet<String>();
        int previousOrder = Integer.MIN_VALUE;
        for (PedidoImportValidator validator : validators) {
            String identifier = validator.identifier();
            if (validator.order() < previousOrder
                    || identifier == null
                    || identifier.length() == 0
                    || !identifiers.add(identifier)) {
                throw new XmlImportException(
                        "Contrato dos validadores descobertos é inválido");
            }
            previousOrder = validator.order();
        }
    }
}
