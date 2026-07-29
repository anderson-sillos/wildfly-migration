# Passos da migração

Esta área documenta incompatibilidades, tentativas antes da correção,
diagnósticos, correções, verificações e rollback na ordem em que ocorrerem.
Os passos sempre alteram a mesma árvore `app/`; não existem implementações
paralelas do estado legado e do moderno.

O índice legível por máquina fica em
[`migration/incompatibilities.tsv`](../incompatibilities.tsv), e novos
registros usam o
[`template de incompatibilidade`](../incompatibility-template.md). Desde a
fase 2, cada ID liga esse relato às evidências sanitizadas de antes e depois.

Registros atuais:

- [`CP-1C-legacy-build-https.md`](CP-1C-legacy-build-https.md): TLS 1.2,
  truststore do Java 7 e compatibilidade dos plugins Maven;
- [`CP-1F-commons-fileupload-commons-io.md`](CP-1F-commons-fileupload-commons-io.md):
  dependência opcional necessária em execução;
- [`CP-1F-reflections-optional-slf4j.md`](CP-1F-reflections-optional-slf4j.md):
  dependência implícita do módulo SLF4J do WildFly 9;
- [`CP-1F-validator-after-xsd.md`](CP-1F-validator-after-xsd.md):
  prova funcional do validador descoberto;
- [`CP-1F-xmlbeans-xsd-regex.md`](CP-1F-xmlbeans-xsd-regex.md):
  interpretação histórica de expressão regular pelo XMLBeans.
