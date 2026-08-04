# CP-3G/3.32 — multipart nativo do Servlet

## Decisão

Commons FileUpload 1.x foi removido do caminho Jakarta. `UploadServlet` e
`XmlImportServlet` agora usam `@MultipartConfig` e `jakarta.servlet.http.Part`,
sem parser externo, sem API `javax.servlet` e sem Commons IO no WAR.

Os limites do contrato anterior foram preservados:

- anexo: 512 KiB por arquivo e 576 KiB por requisição;
- importação XML: 128 KiB por arquivo e 160 KiB por requisição;
- threshold de 32 KiB para o armazenamento temporário do contêiner;
- exatamente um campo de arquivo (`arquivo` ou `arquivoXml`);
- nome enviado reduzido ao basename antes da persistência;
- leitura limitada, validação de arquivo vazio e limpeza de cada `Part` em
  `finally`.

## Compatibilidade e impacto

`request.getParts()` e `Part.getSubmittedFileName()` são APIs padrão do
Servlet 3.1+ e fazem parte do Jakarta Servlet 6.1 usado no WildFly 41. O
contêiner passa a controlar o armazenamento temporário e a rejeição de
`maxFileSize`/`maxRequestSize`; a aplicação mantém uma leitura limitada como
defesa adicional antes de persistir o conteúdo.

O contrato transitório do CP-3B continua preservado apenas nas evidências e no
runtime Java 17/WildFly 26. Ele não é reintroduzido no WAR Jakarta.

## Validação

```bash
./scripts/validate-cp-3g-upload.sh
./scripts/rebuild-cp-3f-ide.sh --env .env
./scripts/smoke-wildfly41-datasource.sh \
  --profile ci-h2 --env .env \
  --war app/target/wildfly-migration.war \
  --result /tmp/cp3g-upload-h2.json
```

A suíte HTTP existente comprova upload válido, basename normalizado,
metadados persistidos, limite `413`, importação XML e ausência de temporários
deixados pelo processamento.

## Rollback

O rollback é o estado aprovado do CP-3F, que restaura a ponte
`JakartaFileUploadRequestContext` e as dependências FileUpload/Commons IO no
WAR. Nenhum schema ou dado Oracle é alterado pela troca.
