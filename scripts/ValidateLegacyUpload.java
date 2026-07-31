import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.Charset;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public final class ValidateLegacyUpload {
    private ValidateLegacyUpload() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException(
                    "uso: ValidateLegacyUpload <raiz-do-repositorio>");
        }
        File repository = new File(args[0]);
        validatePom(read(file(repository, "app/pom.xml")));
        validateWebXml(parse(file(
                repository, "app/src/main/webapp/WEB-INF/web.xml")));
        validateServlet(read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/web/"
                + "UploadServlet.java")));
        validateRepository(read(file(
                repository,
                "app/src/main/java/br/com/asillos/migration/persistence/"
                + "AnexoRepository.java")));
        validateMapper(read(file(
                repository,
                "app/src/main/resources/mybatis/AnexoMapper.xml")));
        validateView(read(file(
                repository,
                "app/src/main/webapp/WEB-INF/views/pedidos/"
                + "detalhe-content.jsp")));
        System.out.println(
                "OK: upload Commons FileUpload 1.6.0 e metadados validados");
    }

    private static void validatePom(String pom) {
        require(pom.indexOf(
                "<commons.fileupload.version>1.6.0"
                + "</commons.fileupload.version>") >= 0,
                "Commons FileUpload 1.6.0 não está fixado");
        require(pom.indexOf(
                "<commons.io.version>2.19.0</commons.io.version>") >= 0,
                "Commons IO 2.19.0 não está fixado");
        require(pom.indexOf("<artifactId>commons-io</artifactId>") >= 0,
                "dependência opcional do FileUpload não foi declarada");
    }

    private static void validateWebXml(Document document) {
        require(countText(document, "servlet-class",
                "br.com.asillos.migration.web.UploadServlet") == 1,
                "UploadServlet deve ocorrer uma vez");
        require(countText(document, "url-pattern", "/anexos/upload") == 1,
                "mapeamento /anexos/upload ausente");
    }

    private static void validateServlet(String source) {
        require(source.indexOf(
                "ServletFileUpload.isMultipartContent(request)") >= 0,
                "upload não exige multipart/form-data");
        require(source.indexOf(
                "upload.setFileSizeMax(AnexoRepository.MAX_FILE_BYTES)") >= 0,
                "limite por arquivo não foi configurado");
        require(source.indexOf(
                "upload.setSizeMax(MAX_REQUEST_BYTES)") >= 0,
                "limite da requisição não foi configurado");
        require(source.indexOf(
                "MAX_REQUEST_BYTES = 576L * 1024L") >= 0,
                "limite da requisição deve ser 576 KiB");
        require(source.indexOf(
                "MEMORY_THRESHOLD_BYTES = 32 * 1024") >= 0,
                "threshold de memória deve ser 32 KiB");
        require(source.indexOf("item.delete()") >= 0,
                "itens temporários não são eliminados");
        require(source.indexOf("FileItem.write") < 0,
                "upload não deve gravar arquivo fornecido pelo cliente");
    }

    private static void validateRepository(String source) {
        require(source.indexOf(
                "MAX_FILE_BYTES = 512L * 1024L") >= 0,
                "limite do arquivo deve ser 512 KiB");
        require(source.indexOf(
                "MessageDigest.getInstance(\"SHA-256\")") >= 0,
                "SHA-256 não é calculado no servidor");
        require(source.indexOf("value.replace('\\\\', '/')") >= 0,
                "nome do cliente não é reduzido ao basename");
        require(source.indexOf("anexo.setTamanhoBytes(") >= 0,
                "tamanho calculado não é persistido");
        require(source.indexOf("anexo.setTipoConteudo(contentType)") >= 0,
                "tipo normalizado não é persistido");
    }

    private static void validateMapper(String mapper) {
        int metadataStart =
                mapper.indexOf("<sql id=\"anexoMetadataColumns\">");
        int metadataEnd = mapper.indexOf("</sql>", metadataStart);
        require(metadataStart >= 0 && metadataEnd > metadataStart,
                "colunas de metadados do anexo ausentes");
        String metadata = mapper.substring(metadataStart, metadataEnd);
        require(metadata.indexOf("SHA256") >= 0
                && metadata.indexOf("TAMANHO_BYTES") >= 0,
                "metadados comparáveis incompletos");
        require(metadata.indexOf("SHA256, CONTEUDO") < 0,
                "listagem de metadados não deve carregar o BLOB");
        require(mapper.indexOf(
                "<include refid=\"anexoMetadataColumns\"/>") >= 0,
                "listagem não usa as colunas sem BLOB");
        require(mapper.indexOf(
                "<select id=\"listarPorPedido\" "
                + "resultMap=\"anexoMetadataResult\">") >= 0,
                "listagem não usa o resultMap sem BLOB");
    }

    private static void validateView(String view) {
        require(view.indexOf("enctype=\"multipart/form-data\"") >= 0,
                "formulário multipart ausente");
        require(view.indexOf("name=\"arquivo\"") >= 0,
                "campo de arquivo ausente");
        require(view.indexOf("data-upload-status=\"ok\"") >= 0,
                "marcador de sucesso do upload ausente");
        require(view.indexOf("${anexo.nomeArquivo}") >= 0
                && view.indexOf("${anexo.tipoConteudo}") >= 0
                && view.indexOf("${anexo.tamanhoBytes}") >= 0
                && view.indexOf("${anexo.sha256}") >= 0
                && view.indexOf("${anexo.criadoEm}") >= 0,
                "metadados comparáveis não são exibidos");
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
                "http://xml.org/sax/features/external-parameter-entities",
                false);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        return factory.newDocumentBuilder().parse(file);
    }

    private static int countText(
            Document document, String localName, String expected) {
        NodeList nodes = document.getElementsByTagNameNS("*", localName);
        int matches = 0;
        for (int index = 0; index < nodes.getLength(); index++) {
            Node node = nodes.item(index);
            if (expected.equals(node.getTextContent().trim())) {
                matches++;
            }
        }
        return matches;
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
