# CP-3B — Commons FileUpload 1.x transitório

## Decisão da atividade 3.8

O gate Java 17/WildFly 26 atualiza:

- `commons-fileupload:commons-fileupload` de 1.2.2 para 1.6.0;
- `commons-io:commons-io` de 1.3.2 para 2.19.0.

FileUpload 1.6.0 é a última versão aprovada da linha 1.x para este gate. A
linha preserva os pacotes `org.apache.commons.fileupload` e o contrato Servlet
`javax`, por isso não antecipa a migração Jakarta. Commons IO permanece uma
dependência direta e com versão explícita para que o conteúdo do WAR não
dependa de resolução opcional ou de bibliotecas do servidor.

A troca é transitória. A atividade 3.32 removerá Commons FileUpload e usará
`@MultipartConfig`/`jakarta.servlet.http.Part` no destino Jakarta EE 11.

## Contrato preservado

O código continua usando `ServletFileUpload`, `DiskFileItemFactory` e
`FileItem`. Permanecem inalterados:

- somente uma parte chamada `arquivo`;
- arquivo máximo de 512 KiB;
- requisição multipart máxima de 576 KiB;
- threshold de 32 KiB no tempdir do contêiner;
- normalização do nome fornecido pelo cliente;
- MIME, tamanho, SHA-256 e BLOB persistidos na mesma transação;
- `FileItem.delete()` em `finally`.

O namespace `javax.servlet` continua sendo fornecido pelo WildFly; nenhuma API
Servlet é empacotada no WAR.

## Qualificação

```bash
./scripts/qualify-cp-3b-h2.sh --env .env
./scripts/qualify-cp-3b-oracle.sh --env .env
```

Além dos 14 contratos HTTP, a sonda da atividade comprova:

- upload válido com `../` no nome e basename normalizado;
- round-trip dos metadados e do conteúdo;
- HTTP `413` para arquivo de 512 KiB mais um byte;
- HTTP `413` para requisição acima de 576 KiB;
- ausência de temporários `upload_*` deixados pelo parser;
- exatamente um JAR FileUpload 1.6.0 e um Commons IO 2.19.0 no WAR.

Os relatórios `cp-3b-upload-ci-h2.json` e
`cp-3b-upload-oracle.json` são sanitizados e não registram nomes internos,
conteúdo enviado nem configuração do Oracle.

## Limite da comprovação

O resultado cobre a API e os limites usados pelo laboratório. Uma aplicação
real deve inventariar factories personalizadas, listeners de progresso,
streaming API, serialização de `FileItem` e acesso direto a arquivos
temporários antes de aplicar a mesma troca.

## Rollback

O commit verde anterior é
`e73f3184917984062d9ce8037d75236631399d99`. Ele mantém MyBatis 3.5.19 e a
ponte de logging, restaurando apenas FileUpload 1.2.2 e Commons IO 1.3.2.
