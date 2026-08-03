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

O FileUpload 1.6.0 ainda é uma exceção transitória: ele declara sobrecargas
`javax.servlet` mesmo quando o código da aplicação já usa Jakarta. O adaptador
`JakartaFileUploadRequestContext` evita que essa assinatura apareça no bytecode
da aplicação e será removido junto com a biblioteca na atividade 3.32.

## Limite do gate

O build Jakarta passa, mas a implantação completa ainda encontra
`TilesListener` porque Apache Tiles 2.1.4 só implementa
`javax.servlet.ServletContextListener`. Essa é a incompatibilidade esperada
que será resolvida na atividade 3.31, sem atualizar Tiles para outra versão
descontinuada. Por isso, os contratos de listagem/criação/consulta/sessão e o
encerramento do CP-3F permanecem pendentes até a decisão de sequência entre
este gate e a substituição do layout.

## Validação

```bash
./scripts/validate-cp-3f-namespace.sh
./scripts/build-cp-3f-jakarta.sh --env .env
```

O resultado do build e o registro do TLD ficam em
[`migration/evidence/CP-3F`](../migration/evidence/CP-3F/).

Rollback: retornar ao commit integrado do CP-3E e ao perfil
`cp-3e-jakarta11`/WAR aprovado anteriormente, sem alterar dados do Oracle.
