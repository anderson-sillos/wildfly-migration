import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public final class ValidateApplicationPom {
    private static final String POM_NAMESPACE =
            "http://maven.apache.org/POM/4.0.0";

    private ValidateApplicationPom() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateApplicationPom <raiz-do-repositorio>");
        }

        File repository = new File(args[0]);
        Document pom = parse(file(repository, "app/pom.xml"));
        validateProject(pom);
        validateWebXml(parse(file(
                repository, "app/src/main/webapp/WEB-INF/web.xml")));
        validateDeploymentStructure(parse(file(
                repository,
                "app/src/main/webapp/WEB-INF/"
                + "jboss-deployment-structure.xml")));
        validateOracleModule(parse(file(
                repository,
                "runtime/legacy/ojdbc7/module.xml.template")));
        validateH2Module(parse(file(
                repository,
                "runtime/legacy/h2/module.xml")));
        validateDatasourceContract(file(
                repository,
                "runtime/legacy/datasource-contract.properties"));

        System.out.println(
                "OK: POM ativo, WAR e contrato de datasource validados");
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        if (!result.isFile()) {
            throw new IllegalArgumentException("arquivo ausente: " + relativePath);
        }
        return result;
    }

    private static Document parse(File file) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities", false);
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities", false);
        factory.setFeature(
                "http://apache.org/xml/features/nonvalidating/load-external-dtd",
                false);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");

        DocumentBuilder builder = factory.newDocumentBuilder();
        return builder.parse(file);
    }

    private static void validateProject(Document document) {
        Element project = document.getDocumentElement();
        require("project".equals(project.getLocalName()), "raiz do POM inválida");
        require(POM_NAMESPACE.equals(project.getNamespaceURI()),
                "namespace do POM inválido");
        require("4.0.0".equals(text(project, "modelVersion")),
                "modelVersion do POM deve permanecer em 4.0.0");
        require("war".equals(text(project, "packaging")),
                "packaging deve ser war");

        Element propertiesElement = child(project, "properties");
        Map<String, String> properties = new LinkedHashMap<String, String>();
        NodeList propertyNodes = propertiesElement.getChildNodes();
        for (int index = 0; index < propertyNodes.getLength(); index++) {
            Node node = propertyNodes.item(index);
            if (node instanceof Element) {
                properties.put(node.getLocalName(), node.getTextContent().trim());
            }
        }

        require("17".equals(properties.get("maven.compiler.source")),
                "source do compilador deve ser 17 no gate CP-3A");
        require("17".equals(properties.get("maven.compiler.target")),
                "target do compilador deve ser 17 no gate CP-3A");
        require("[17,18)".equals(
                properties.get("java.version.range")),
                "range Java padrão deve exigir a família Java 17");

        Map<String, String[]> expected =
                new LinkedHashMap<String, String[]>();
        expected.put("jakarta.platform:jakarta.jakartaee-web-api",
                values("8.0.0", "provided"));
        expected.put("org.mybatis:mybatis", values("3.5.19", "compile"));
        expected.put("org.slf4j:log4j-over-slf4j",
                values("1.7.36", "compile"));
        expected.put("org.slf4j:slf4j-api",
                values("1.7.36", "provided"));
        expected.put("commons-fileupload:commons-fileupload",
                values("1.6.0", "compile"));
        expected.put("commons-io:commons-io",
                values("2.19.0", "compile"));
        expected.put("org.reflections:reflections",
                values("0.9.10", "compile"));
        expected.put("org.apache.tiles:tiles-api",
                values("2.1.4", "compile"));
        expected.put("org.apache.tiles:tiles-jsp",
                values("2.1.4", "compile"));
        expected.put("org.apache.xmlbeans:xmlbeans",
                values("2.3.0", "compile"));
        expected.put("xml-apis:xml-apis",
                values("1.3.02", "compile"));
        expected.put(
                "org.apache.geronimo.specs:geronimo-stax-api_1.0_spec",
                values("1.0", "compile"));
        expected.put("dom4j:dom4j", values("1.6.1", "compile"));

        Element dependencies = child(project, "dependencies");
        NodeList dependencyNodes = dependencies.getChildNodes();
        int dependencyCount = 0;
        for (int index = 0; index < dependencyNodes.getLength(); index++) {
            Node node = dependencyNodes.item(index);
            if (!(node instanceof Element)
                    || !"dependency".equals(node.getLocalName())) {
                continue;
            }
            dependencyCount++;
            Element dependency = (Element) node;
            String coordinate =
                    text(dependency, "groupId") + ":"
                    + text(dependency, "artifactId");
            String[] rule = expected.get(coordinate);
            require(rule != null, "dependência direta inesperada: " + coordinate);

            String version = resolve(
                    text(dependency, "version"), properties);
            String scope = optionalText(dependency, "scope");
            if (scope.length() == 0) {
                scope = "compile";
            }
            require(rule[0].equals(version),
                    "versão divergente para " + coordinate);
            require(rule[1].equals(scope),
                    "escopo divergente para " + coordinate);
            require(optionalText(dependency, "systemPath").length() == 0,
                    "systemPath é proibido: " + coordinate);
            require(!"system".equals(scope),
                    "escopo system é proibido: " + coordinate);
        }
        require(dependencyCount == expected.size(),
                "quantidade de dependências diretas divergente");

        require(document.getElementsByTagNameNS(POM_NAMESPACE, "repositories")
                .getLength() == 0,
                "repositórios adicionais são proibidos no POM da aplicação");

        Element build = child(project, "build");
        require("wildfly-migration".equals(text(build, "finalName")),
                "finalName do WAR divergente");

        Map<String, String> expectedPlugins =
                new LinkedHashMap<String, String>();
        expectedPlugins.put("maven-enforcer-plugin", "3.0.0-M3");
        expectedPlugins.put("maven-compiler-plugin", "3.8.1");
        expectedPlugins.put("maven-war-plugin", "3.3.2");
        expectedPlugins.put("maven-dependency-plugin", "3.1.2");

        Element plugins = child(build, "plugins");
        NodeList pluginNodes = plugins.getChildNodes();
        int pluginCount = 0;
        for (int index = 0; index < pluginNodes.getLength(); index++) {
            Node node = pluginNodes.item(index);
            if (!(node instanceof Element)
                    || !"plugin".equals(node.getLocalName())) {
                continue;
            }
            pluginCount++;
            Element plugin = (Element) node;
            String artifactId = text(plugin, "artifactId");
            String expectedVersion = expectedPlugins.get(artifactId);
            require(expectedVersion != null,
                    "plugin inesperado: " + artifactId);
            require(expectedVersion.equals(text(plugin, "version")),
                    "versão divergente do plugin " + artifactId);
            if ("maven-enforcer-plugin".equals(artifactId)) {
                Element requireMaven =
                        uniqueDescendant(plugin, "requireMavenVersion");
                Element requireJava =
                        uniqueDescendant(plugin, "requireJavaVersion");
                require("[3.9.16]".equals(text(requireMaven, "version")),
                        "Enforcer deve exigir exatamente Maven 3.9.16");
                require("${java.version.range}".equals(
                        text(requireJava, "version")),
                        "Enforcer deve usar o range Java ativo");
            }
        }
        require(pluginCount == expectedPlugins.size(),
                "quantidade de plugins divergente");

        Map<String, String> expectedProfiles =
                new LinkedHashMap<String, String>();
        expectedProfiles.put("oracle", "[17,18)");
        expectedProfiles.put("ci-h2", "[17,18)");

        Element profiles = child(project, "profiles");
        NodeList profileNodes = profiles.getChildNodes();
        int profileCount = 0;
        for (int index = 0; index < profileNodes.getLength(); index++) {
            Node node = profileNodes.item(index);
            if (!(node instanceof Element)
                    || !"profile".equals(node.getLocalName())) {
                continue;
            }
            profileCount++;
            Element profile = (Element) node;
            String profileId = text(profile, "id");
            String expectedRange = expectedProfiles.get(profileId);
            require(expectedRange != null,
                    "perfil Maven inesperado: " + profileId);
            Element profileProperties = child(profile, "properties");
            require(expectedRange.equals(
                    text(profileProperties, "java.version.range")),
                    "range Java divergente no perfil " + profileId);
        }
        require(profileCount == expectedProfiles.size(),
                "quantidade de perfis Maven divergente");
    }

    private static void validateWebXml(Document document) {
        Element webApp = document.getDocumentElement();
        require("web-app".equals(webApp.getLocalName()),
                "raiz de web.xml inválida");
        require("http://java.sun.com/xml/ns/j2ee".equals(
                webApp.getNamespaceURI()),
                "namespace legado de web.xml divergente");
        require("2.4".equals(webApp.getAttribute("version")),
                "web.xml deve declarar Servlet 2.4");
    }

    private static void validateDeploymentStructure(Document document) {
        Element structure = document.getDocumentElement();
        require("jboss-deployment-structure".equals(
                structure.getLocalName()),
                "raiz de jboss-deployment-structure.xml inválida");
        NodeList modules =
                document.getElementsByTagNameNS("*", "module");
        require(modules.getLength() == 1,
                "deployment deve excluir somente um módulo");
        Element module = (Element) modules.item(0);
        require("org.apache.log4j".equals(module.getAttribute("name")),
                "módulo Log4j 1 do WildFly deve ser excluído");
    }

    private static void validateOracleModule(Document document) {
        Element module = document.getDocumentElement();
        require("module".equals(module.getLocalName()),
                "raiz do módulo Oracle inválida");
        require("com.oracle.ojdbc7".equals(module.getAttribute("name")),
                "nome do módulo Oracle divergente");

        NodeList resources =
                document.getElementsByTagNameNS("*", "resource-root");
        require(resources.getLength() == 1,
                "módulo Oracle deve declarar um único resource-root");
        Element resource = (Element) resources.item(0);
        require("ojdbc7.jar".equals(resource.getAttribute("path")),
                "módulo Oracle deve usar ojdbc7.jar externo");
    }

    private static void validateH2Module(Document document) {
        Element module = document.getDocumentElement();
        require("module".equals(module.getLocalName()),
                "raiz do módulo H2 inválida");
        require("com.h2database.h2.cp1d".equals(module.getAttribute("name")),
                "nome do módulo H2 divergente");

        NodeList resources =
                document.getElementsByTagNameNS("*", "resource-root");
        require(resources.getLength() == 1,
                "módulo H2 deve declarar um único resource-root");
        Element resource = (Element) resources.item(0);
        require("h2-1.4.200.jar".equals(resource.getAttribute("path")),
                "módulo H2 deve usar h2-1.4.200.jar externo");
    }

    private static void validateDatasourceContract(File file) throws Exception {
        Properties properties = new Properties();
        InputStream input = new FileInputStream(file);
        try {
            properties.load(input);
        } finally {
            input.close();
        }
        require("java:/jdbc/MigrationDS".equals(
                properties.getProperty("datasource.jndi-name")),
                "JNDI legado divergente");
        require("MigrationDS".equals(
                properties.getProperty("datasource.pool-name")),
                "pool legado divergente");
        require("false".equals(
                properties.getProperty("datasource.jta")),
                "datasource legado deve usar transação local do MyBatis");
        require("h2-cp1d".equals(
                properties.getProperty("profile.ci-h2.driver.name")),
                "nome do driver H2 divergente");
        require("com.h2database.h2.cp1d".equals(
                properties.getProperty("profile.ci-h2.driver.module")),
                "módulo do driver H2 divergente");
        require("org.h2.Driver".equals(
                properties.getProperty("profile.ci-h2.driver.class")),
                "classe do driver H2 divergente");
        require("oracle".equals(
                properties.getProperty("profile.oracle.driver.name")),
                "nome do driver Oracle divergente");
        require("com.oracle.ojdbc7".equals(
                properties.getProperty("profile.oracle.driver.module")),
                "módulo do driver Oracle divergente");
        require("oracle.jdbc.OracleDriver".equals(
                properties.getProperty("profile.oracle.driver.class")),
                "classe do driver divergente");
    }

    private static String[] values(String version, String scope) {
        return new String[] {version, scope};
    }

    private static String resolve(
            String value, Map<String, String> properties) {
        if (value.startsWith("${") && value.endsWith("}")) {
            String property = value.substring(2, value.length() - 1);
            String resolved = properties.get(property);
            require(resolved != null, "propriedade Maven ausente: " + property);
            return resolved;
        }
        return value;
    }

    private static Element child(Element parent, String localName) {
        NodeList nodes = parent.getChildNodes();
        for (int index = 0; index < nodes.getLength(); index++) {
            Node node = nodes.item(index);
            if (node instanceof Element
                    && localName.equals(node.getLocalName())) {
                return (Element) node;
            }
        }
        throw new IllegalArgumentException(
                "elemento obrigatório ausente: " + localName);
    }

    private static String text(Element parent, String localName) {
        return child(parent, localName).getTextContent().trim();
    }

    private static String optionalText(Element parent, String localName) {
        NodeList nodes = parent.getChildNodes();
        for (int index = 0; index < nodes.getLength(); index++) {
            Node node = nodes.item(index);
            if (node instanceof Element
                    && localName.equals(node.getLocalName())) {
                return node.getTextContent().trim();
            }
        }
        return "";
    }

    private static Element uniqueDescendant(
            Element parent, String localName) {
        NodeList nodes = parent.getElementsByTagNameNS("*", localName);
        require(nodes.getLength() == 1,
                "elemento deve ocorrer uma vez: " + localName);
        return (Element) nodes.item(0);
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
