# Passos da migração

Esta área documentará incompatibilidades, tentativas antes da correção,
diagnósticos, correções, verificações e rollback na ordem em que ocorrerem.

Os passos sempre alteram a mesma árvore `app/`. Eles não mantêm implementações
paralelas do estado legado e do estado moderno.

Registros atuais:

- [`CP-1C-legacy-build-https.md`](CP-1C-legacy-build-https.md): TLS 1.2,
  truststore do Java 7 e compatibilidade dos plugins Maven.
