# CP-3F — Namespaces e descritores Jakarta

Este gate migra a camada web da aplicação para o namespace Jakarta EE 11,
mantendo o mesmo domínio, persistência e contrato HTTP. O perfil de build é
`cp-3e-jakarta11`, com Java 21, Maven 3.9.16 e
`jakarta.platform:jakarta.jakartaee-web-api:11.0.0` em `provided`.

## Alterações concluídas

- Servlets, filtros, listeners, sessão e o handler da tag usam
  `jakarta.servlet.*` e `jakarta.servlet.jsp.tagext.*`.
- `javax.sql`, `javax.naming` e `javax.xml` continuam inalterados: pertencem
  ao Java SE e não fazem parte da migração EE.
- `web.xml` usa o namespace Jakarta EE, Servlet 6.1 e o schema
  `web-app_6_1.xsd`.
- As JSPs usam `jakarta.tags.core` e `jakarta.tags.fmt`.
- O TLD customizado mantém o URI funcional, mas usa o schema Jakarta JSP
  `web-jsptaglibrary_3_0` e o handler Jakarta.
- O arquivo histórico 2.0 foi preservado em
  [`tld-historical.xml`](../migration/evidence/CP-3F/tld-historical.xml) antes
  da normalização. Sua tentativa no WildFly 41 foi rejeitada por depender do
  namespace Servlet/JSP legado, conforme o registro do gate.

O bloqueio transitório do FileUpload 1.6.0 foi capturado no primeiro contrato
multipart. A atividade 3.32 removeu a biblioteca e o adaptador, substituindo-os
por `@MultipartConfig` e `jakarta.servlet.http.Part`; os contratos H2 e Oracle
continuam preservando limites, normalização e limpeza.

## Limite do gate

O registro em [`deployment-tiles-blocked.txt`](../migration/evidence/CP-3F/deployment-tiles-blocked.txt)
preserva a falha histórica do primeiro deployment. A atividade 3.31 removeu
Tiles por meio de um tag file JSP e includes sob `WEB-INF`; a tentativa
posterior no WildFly 41 deixou de falhar por `TilesListener` e os contratos
H2 e Oracle passaram na tarefa 3.29. A tarefa 3.30 ainda precisa versionar os
relatórios sanitizados, consolidar a auditoria e registrar o rollback.

Durante a mesma execução, o Commons FileUpload 1.6.0 revelou a assinatura
`javax.servlet` somente ao processar o primeiro multipart. O diagnóstico da
ponte transitória está em [`INC-017`](../migration/steps/CP-3F-fileupload-jakarta-linkage.md);
a correção definitiva e a evidência estão em
[`CP-3G-servlet-multipart.md`](../migration/steps/CP-3G-servlet-multipart.md).

## Validação

```bash
./scripts/validate-cp-3f-namespace.sh
./scripts/validate-cp-3g-tiles.sh
./scripts/validate-cp-3f-closure.sh
./scripts/build-cp-3f-jakarta.sh --env .env
```

O resultado do build e o registro do TLD ficam em
[`migration/evidence/CP-3F`](../migration/evidence/CP-3F/).

## JDT no VS Code

O workspace usa Temurin 21 como JDK padrão do JDT. O profile
`cp-3e-jakarta11` também é ativado automaticamente quando o Maven é importado
com Java 21; os gates históricos continuam usando Java 17 e seus profiles
explícitos.

Para regenerar os tipos XMLBeans no diretório que o JDT acompanha, execute a
task **Build: limpar bytecode e reconstruir (Java 21/Jakarta/H2)**. Ela chama o
script exclusivo `scripts/rebuild-cp-3f-ide.sh` e grava em
`app/target/generated-sources`, sem atualizar as evidências do CP-3F. Depois
execute `Java: Clean Java Language Server Workspace` e recarregue a janela do
VS Code. Não edite os arquivos gerados e não inclua `app/target` no Git.

Rollback: retornar ao commit integrado do CP-3E e ao perfil
`cp-3e-jakarta11`/WAR aprovado anteriormente, sem alterar dados do Oracle.
