# Upload legado do CP-1F

O primeiro incremento do CP-1F usa deliberadamente
`commons-fileupload:commons-fileupload:1.2.2` para reproduzir o acoplamento da
aplicação original. Essa versão é histórica, sem manutenção e inadequada para
produção. O laboratório continua restrito a loopback ou à rede interna.

O primeiro smoke reproduziu `NoClassDefFoundError` para
`DeferredFileOutputStream`: a versão 1.2.2 declara `commons-io:1.3.2` como
opcional. A menor correção foi declarar essa mesma versão diretamente, elevando
o WAR de 19 para 20 bibliotecas. O registro antes/depois está em
[CP-1F — dependência opcional do FileUpload](../migration/steps/CP-1F-commons-fileupload-commons-io.md).

## Contrato funcional

O detalhe de um pedido publica um formulário `multipart/form-data` para:

```text
POST /wildfly-migration/anexos/upload?pedidoId=<ID>
```

A requisição deve conter exatamente uma parte de arquivo chamada `arquivo`.
Não são aceitos campos adicionais, arquivo vazio ou pedido inexistente.

| Regra | Valor |
| --- | --- |
| arquivo máximo | 512 KiB (`524288` bytes) |
| requisição multipart máxima | 576 KiB (`589824` bytes) |
| threshold em memória | 32 KiB; acima disso o parser usa o tempdir do servlet |
| quantidade de arquivos | exatamente um |

O limite de requisição reserva 64 KiB para cabeçalhos e delimitadores
multipart. O `finally` chama `FileItem.delete()` para remover qualquer arquivo
temporário criado pelo parser.

## Metadados comparáveis

O servidor não confia em metadados calculados pelo cliente. Antes da inclusão,
ele:

1. reduz caminhos Unix ou Windows ao nome base;
2. rejeita nome vazio, `.`/`..`, controles ou mais de 255 caracteres;
3. normaliza o MIME para minúsculas, sem parâmetros, e usa
   `application/octet-stream` quando o valor não é estruturalmente seguro;
4. calcula o tamanho a partir do `byte[]` recebido;
5. calcula SHA-256 em minúsculas;
6. persiste metadados e BLOB na mesma transação MyBatis.

O detalhe do pedido lista `nomeArquivo`, `tipoConteudo`, `tamanhoBytes`,
`sha256` e `criadoEm`. Essa listagem usa uma projeção sem `CONTEUDO`; o BLOB
somente é carregado pela consulta individual do anexo. Os mesmos valores são
comparáveis no H2 e no Oracle 19c.

## Respostas controladas

- sucesso: redirect `303/302` para o detalhe com `upload=ok`;
- multipart inválido ou metadado rejeitado: HTTP `400`;
- arquivo ou requisição acima do limite: HTTP `413`;
- persistência indisponível: HTTP `503`.

As mensagens não reproduzem exceções, nomes temporários, URL JDBC ou
credenciais. Toda resposta passa pelo filtro de correlação já existente.

## Validação

```bash
./scripts/validate-cp-1f-upload.sh
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war
```

O smoke cria um pedido transitório, envia um arquivo com caminho fornecido pelo
cliente, compara nome normalizado, MIME, tamanho e SHA-256 e confirma HTTP `413`
para 512 KiB mais um byte. No perfil Oracle, anexos do pedido
`LAB-SMOKE-*` são removidos antes da limpeza do próprio pedido.

Os contratos HTTP independentes do WAR serão consolidados na tarefa `1.29`.
No destino Jakarta, a tarefa `3.32` substituirá esta biblioteca por
`@MultipartConfig` e `jakarta.servlet.http.Part`, preservando o contrato.
