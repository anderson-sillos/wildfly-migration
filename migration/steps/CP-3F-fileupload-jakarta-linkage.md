# INC-017 / CP-3F — Commons FileUpload 1.x e assinaturas `javax`

## Sintoma reproduzido

Depois que o Tiles foi removido, o WAR Jakarta foi implantado no WildFly 41,
mas a primeira requisição multipart falhou com:

```text
java.lang.NoClassDefFoundError: javax/servlet/http/HttpServletRequest
```

O erro não ocorreu no deployment: ele foi provocado quando a API do Commons
FileUpload 1.6.0 resolveu os métodos de conveniência baseados em
`HttpServletRequest`.

## Correção transitória do gate

O adaptador Jakarta mantém apenas a interface neutra `RequestContext` e usa
`MethodHandles` para invocar a sobrecarga `parseRequest(RequestContext)` sem
colocar a assinatura `javax.servlet` no bytecode da aplicação. O contrato H2
do CP-3F voltou a passar, incluindo upload, limite de tamanho e metadados.

## Destino

Esta é uma ponte de compatibilidade, não uma solução final. A atividade 3.32
substituirá Commons FileUpload por `@MultipartConfig` e
`jakarta.servlet.http.Part`, removendo a dependência e o adaptador.

## Aplicação equivalente em produção

Ao migrar uma aplicação real, não adicione `javax.servlet-api` ao WAR Jakarta
para esconder o erro. Identifique a sobrecarga que introduz a assinatura
legada, preserve temporariamente somente o contrato neutro necessário e planeje
a troca pelo multipart nativo do Servlet.
