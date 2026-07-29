package br.com.asillos.migration.persistence;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Date;
import java.util.List;
import java.util.Locale;

import br.com.asillos.migration.domain.Anexo;

import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;

/**
 * Persiste anexos com metadados normalizados e calculados pelo servidor.
 */
public final class AnexoRepository {
    public static final long MAX_FILE_BYTES = 512L * 1024L;

    private static final String DEFAULT_CONTENT_TYPE =
            "application/octet-stream";

    private final MyBatisTransactionTemplate transactions;

    public AnexoRepository(SqlSessionFactory sessionFactory) {
        transactions = new MyBatisTransactionTemplate(sessionFactory);
    }

    public List<Anexo> listarPorPedido(final Long pedidoId) {
        requirePositivePedidoId(pedidoId);
        return transactions.execute(new TransactionWork<List<Anexo>>() {
            @Override
            public List<Anexo> execute(SqlSession session) {
                return session.getMapper(AnexoMapper.class)
                        .listarPorPedido(pedidoId);
            }
        });
    }

    public Anexo buscarPorId(final Long id) {
        if (id == null || id.longValue() <= 0L) {
            throw new IllegalArgumentException(
                    "Identificador do anexo é inválido");
        }
        return transactions.execute(new TransactionWork<Anexo>() {
            @Override
            public Anexo execute(SqlSession session) {
                return session.getMapper(AnexoMapper.class).buscarPorId(id);
            }
        });
    }

    public Anexo criar(
            final Long pedidoId,
            final String clientFileName,
            final String clientContentType,
            final byte[] content) {
        requirePositivePedidoId(pedidoId);
        if (content == null || content.length == 0) {
            throw new IllegalArgumentException("O arquivo está vazio");
        }
        if (content.length > MAX_FILE_BYTES) {
            throw new IllegalArgumentException(
                    "O arquivo excede o limite de 512 KiB");
        }

        final String fileName = normalizeFileName(clientFileName);
        final String contentType = normalizeContentType(clientContentType);
        final String digest = sha256(content);

        return transactions.execute(new TransactionWork<Anexo>() {
            @Override
            public Anexo execute(SqlSession session) {
                PedidoMapper pedidoMapper =
                        session.getMapper(PedidoMapper.class);
                if (pedidoMapper.buscarPorId(pedidoId) == null) {
                    throw new IllegalArgumentException(
                            "Pedido do anexo não foi encontrado");
                }

                AnexoMapper anexoMapper =
                        session.getMapper(AnexoMapper.class);
                Anexo anexo = new Anexo();
                anexo.setId(anexoMapper.proximoId());
                anexo.setPedidoId(pedidoId);
                anexo.setNomeArquivo(fileName);
                anexo.setTipoConteudo(contentType);
                anexo.setTamanhoBytes(Long.valueOf(content.length));
                anexo.setSha256(digest);
                anexo.setConteudo(content);
                anexo.setCriadoEm(new Date());
                if (anexoMapper.inserir(anexo) != 1) {
                    throw new IllegalStateException(
                            "Inclusão do anexo não afetou exatamente uma linha");
                }
                return anexoMapper.buscarPorId(anexo.getId());
            }
        });
    }

    private static void requirePositivePedidoId(Long pedidoId) {
        if (pedidoId == null || pedidoId.longValue() <= 0L) {
            throw new IllegalArgumentException(
                    "Identificador do pedido é inválido");
        }
    }

    private static String normalizeFileName(String value) {
        if (value == null) {
            throw new IllegalArgumentException(
                    "Nome do arquivo é obrigatório");
        }
        String normalized = value.replace('\\', '/');
        int separator = normalized.lastIndexOf('/');
        if (separator >= 0) {
            normalized = normalized.substring(separator + 1);
        }
        normalized = normalized.trim();
        if (normalized.length() == 0
                || ".".equals(normalized)
                || "..".equals(normalized)) {
            throw new IllegalArgumentException(
                    "Nome do arquivo é inválido");
        }
        if (normalized.length() > 255) {
            throw new IllegalArgumentException(
                    "Nome do arquivo excede 255 caracteres");
        }
        for (int index = 0; index < normalized.length(); index++) {
            if (Character.isISOControl(normalized.charAt(index))) {
                throw new IllegalArgumentException(
                        "Nome do arquivo contém caractere inválido");
            }
        }
        return normalized;
    }

    private static String normalizeContentType(String value) {
        if (value == null) {
            return DEFAULT_CONTENT_TYPE;
        }
        String normalized = value.trim().toLowerCase(Locale.ENGLISH);
        int parameter = normalized.indexOf(';');
        if (parameter >= 0) {
            normalized = normalized.substring(0, parameter).trim();
        }
        if (normalized.length() == 0
                || normalized.length() > 127
                || !normalized.matches(
                        "[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+")) {
            return DEFAULT_CONTENT_TYPE;
        }
        return normalized;
    }

    private static String sha256(byte[] content) {
        try {
            byte[] digest =
                    MessageDigest.getInstance("SHA-256").digest(content);
            StringBuilder result = new StringBuilder(64);
            for (int index = 0; index < digest.length; index++) {
                result.append(String.format(
                        Locale.ENGLISH, "%02x",
                        Integer.valueOf(digest[index] & 0xff)));
            }
            return result.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException(
                    "SHA-256 não está disponível no runtime");
        }
    }
}
