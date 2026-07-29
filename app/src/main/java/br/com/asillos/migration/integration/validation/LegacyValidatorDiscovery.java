package br.com.asillos.migration.integration.validation;

import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import br.com.asillos.migration.integration.xml.XmlImportException;

import org.reflections.Reflections;
import org.reflections.scanners.SubTypesScanner;
import org.reflections.util.ClasspathHelper;
import org.reflections.util.ConfigurationBuilder;
import org.reflections.util.FilterBuilder;

/**
 * Descoberta legada isolada para futura substituição por registro explícito.
 */
public final class LegacyValidatorDiscovery {
    private static final String PACKAGE =
            "br.com.asillos.migration.integration.validation";

    private LegacyValidatorDiscovery() {
    }

    public static List<PedidoImportValidator> discover()
            throws XmlImportException {
        ClassLoader classLoader =
                Thread.currentThread().getContextClassLoader();
        ConfigurationBuilder configuration = new ConfigurationBuilder()
                .setUrls(ClasspathHelper.forPackage(PACKAGE, classLoader))
                .filterInputsBy(
                        new FilterBuilder().includePackage(PACKAGE))
                .setScanners(new SubTypesScanner())
                .addClassLoader(classLoader);
        Reflections reflections = new Reflections(configuration);

        Set<Class<? extends PedidoImportValidator>> discovered =
                reflections.getSubTypesOf(PedidoImportValidator.class);
        List<PedidoImportValidator> validators =
                new ArrayList<PedidoImportValidator>();
        try {
            for (Class<? extends PedidoImportValidator> type : discovered) {
                if (!type.isInterface()
                        && !Modifier.isAbstract(type.getModifiers())) {
                    validators.add(type.newInstance());
                }
            }
        } catch (InstantiationException exception) {
            throw new XmlImportException(
                    "Validador descoberto não pôde ser instanciado",
                    exception);
        } catch (IllegalAccessException exception) {
            throw new XmlImportException(
                    "Validador descoberto não é acessível", exception);
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
