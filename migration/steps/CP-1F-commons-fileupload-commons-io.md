# CP-1F — Dependência opcional do Commons FileUpload

## Pré-condição

O WAR do CP-1E continha `commons-fileupload:1.2.2`, mas o fluxo multipart ainda
não havia sido executado. A árvore Maven registrava 19 bibliotecas e não
continha `commons-io`.

## Sintoma observado

No primeiro smoke H2 do upload no WildFly 9, o formulário chegou ao
`UploadServlet`, mas a criação do primeiro `DiskFileItem` respondeu HTTP `500`.
O log temporário apresentou:

```text
java.lang.NoClassDefFoundError:
org/apache/commons/io/output/DeferredFileOutputStream
```

## Causa-raiz

O POM publicado de `commons-fileupload:1.2.2` declara
`commons-io:commons-io:1.3.2` como dependência opcional. Dependências opcionais
não são propagadas para o consumidor, embora o caminho de upload em disco use
classes desse JAR.

## Menor correção

O POM da aplicação declara diretamente:

```text
commons-io:commons-io:1.3.2
```

A versão não foi modernizada neste checkpoint: ela corresponde exatamente à
versão esperada pelo FileUpload histórico e mantém a correção separada da
modernização posterior. A allowlist do WAR passa de 19 para 20 bibliotecas.

## Teste de regressão

```bash
./scripts/validate-cp-1c.sh
./scripts/validate-cp-1f-upload.sh
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war
```

O smoke deve persistir um arquivo, comparar nome, MIME, tamanho e SHA-256 e
receber HTTP `413` para um arquivo de 524289 bytes.

## Rollback

Reverter a dependência e a allowlist restaura a falha natural sem alterar o
runtime ou o banco. Não copie `commons-io.jar` manualmente para `WEB-INF/lib`;
a correção deve continuar rastreada pelo Maven.
