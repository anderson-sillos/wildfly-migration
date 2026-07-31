package br.com.asillos.migration.integration.validation;

import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import br.com.asillos.migration.integration.xml.XmlImportException;

import org.apache.log4j.Logger;
import org.reflections.Reflections;
import org.reflections.scanners.Scanners;
import org.reflections.util.ClasspathHelper;
import org.reflections.util.ConfigurationBuilder;
import org.reflections.util.FilterBuilder;

/**
 * Ponte Reflections 0.10.2 isolada para futura substituição pelo SCI padrão.
 */
public final class LegacyValidatorDiscovery {
    private static final Logger LOGGER =
            Logger.getLogger(LegacyValidatorDiscovery.class);
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
                .setScanners(
                        Scanners.TypesAnnotated,
                        Scanners.SubTypes)
                .setClassLoaders(new ClassLoader[] {classLoader});
        Reflections reflections = new Reflections(configuration);

        Set<Class<?>> discovered =
                reflections.getTypesAnnotatedWith(Validator.class);
        List<PedidoImportValidator> validators =
                new ArrayList<PedidoImportValidator>();
        try {
            for (Class<?> type : discovered) {
                if (PedidoImportValidator.class.isAssignableFrom(type)
                        && !type.isInterface()
                        && !Modifier.isAbstract(type.getModifiers())) {
                    validators.add(type.asSubclass(
                            PedidoImportValidator.class)
                            .getDeclaredConstructor().newInstance());
                }
            }
        } catch (InstantiationException exception) {
            throw new XmlImportException(
                    "Validador descoberto não pôde ser instanciado",
                    exception);
        } catch (IllegalAccessException exception) {
            throw new XmlImportException(
                    "Validador descoberto não é acessível", exception);
        } catch (NoSuchMethodException exception) {
            throw new XmlImportException(
                    "Validador descoberto não possui construtor padrão",
                    exception);
        } catch (java.lang.reflect.InvocationTargetException exception) {
            throw new XmlImportException(
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
        validateContract(validators);
        LOGGER.info(
                "legacy_validator_discovery classloader="
                + classLoader.getClass().getName()
                + " scanners=TypesAnnotated+SubTypes set="
                + describeTypes(validators)
                + " order=" + describe(validators));
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
