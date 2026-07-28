import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

public final class ValidateExternalContracts {
    private ValidateExternalContracts() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateExternalContracts <raiz-do-repositorio>");
        }
        File repository = new File(args[0]);
        String runner = read(file(
                repository, "contract-tests/run.sh"));
        String smoke = read(file(
                repository, "scripts/smoke-wildfly9-datasource.sh"));
        String workflow = read(file(
                repository, ".github/workflows/validate.yml"));

        require(runner.indexOf("--base-url") >= 0
                && runner.indexOf("--profile") >= 0
                && runner.indexOf("--war") >= 0
                && runner.indexOf("--result") >= 0
                && runner.indexOf("--commit") >= 0
                && runner.indexOf("--runtime") >= 0,
                "entradas de proveniência da suíte estão incompletas");
        require(runner.indexOf("ci-h2)") >= 0
                && runner.indexOf("oracle)") >= 0,
                "os dois perfis não reutilizam o mesmo runner");
        String[] requiredScenarios = {
            "\"health\": \"passed\"",
            "\"list\": \"passed\"",
            "\"create\": \"passed\"",
            "\"detail\": \"passed\"",
            "\"session\": \"passed\"",
            "\"upload\": \"passed\"",
            "\"uploadLimit\": \"passed\"",
            "\"xmlForm\": \"passed\"",
            "\"xmlValid\": \"passed\"",
            "\"xmlInvalidXsd\": \"passed\"",
            "\"xmlValidatorRejected\": \"passed\"",
            "\"xmlXxe\": \"passed\"",
            "\"xmlEntityExpansion\": \"passed\"",
            "\"persistedState\": \"passed\""
        };
        for (int index = 0; index < requiredScenarios.length; index++) {
            require(runner.indexOf(requiredScenarios[index]) >= 0,
                    "cenário externo ausente: " + requiredScenarios[index]);
        }
        require(runner.indexOf("\"warSha256\"") >= 0
                && runner.indexOf("\"qualification\"") >= 0,
                "relatório não vincula qualificação e WAR");
        require(runner.indexOf("\"baseUrl\"") < 0
                && runner.indexOf("\"url\"") < 0,
                "relatório não pode registrar a URL do ambiente");
        require(runner.indexOf("br.com.asillos") < 0
                && runner.indexOf("WEB-INF/classes") < 0
                && runner.indexOf("app/target/classes") < 0,
                "suíte externa referencia classes internas do WAR");
        require(smoke.indexOf(
                "\"$REPOSITORY_ROOT/contract-tests/run.sh\"") >= 0
                && smoke.indexOf("--profile \"$PROFILE\"") >= 0,
                "smoke não chama a mesma suíte para ambos os perfis");
        require(workflow.indexOf(
                "app/target/contract-results/ci-h2.json") >= 0,
                "CI não preserva o resultado portable-ci");

        System.out.println(
                "OK: suíte HTTP externa e relatório sanitizado validados");
    }

    private static File file(File repository, String relativePath) {
        File result = new File(repository, relativePath);
        require(result.isFile(), "arquivo ausente: " + relativePath);
        return result;
    }

    private static String read(File file) throws Exception {
        InputStream input = new FileInputStream(file);
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                output.write(buffer, 0, count);
            }
            return new String(
                    output.toByteArray(), Charset.forName("UTF-8"));
        } finally {
            input.close();
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalArgumentException(message);
        }
    }
}
