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
  interpretação histórica de expressão regular pelo XMLBeans;
- [`CP-1G-oracle-ru-detection.md`](CP-1G-oracle-ru-detection.md):
  separação entre produto JDBC e Release Update observado no banco.
- [`CP-3B-reflections-0.10.2.md`](CP-3B-reflections-0.10.2.md):
  scanners e classloader explícitos para preservar a descoberta anotada.
- [`CP-3C-xmlbeans-5.3.0.md`](CP-3C-xmlbeans-5.3.0.md):
  geração dos tipos pelo XSD e round-trip seguro de XMLBeans 5.3.0.
- [`CP-3C-dom4j-2.2.0.md`](CP-3C-dom4j-2.2.0.md):
  mudança de coordenada, parsing legítimo e rejeição de XXE/entidades.
- [`CP-3C-java-xml-apis.md`](CP-3C-java-xml-apis.md):
  remoção de APIs XML duplicadas e uso do módulo `java.xml`.
- [`CP-3C-ojdbc17.md`](CP-3C-ojdbc17.md):
  troca controlada do driver Oracle externo no gate Java 17.
- [`CP-3F-fileupload-jakarta-linkage.md`](CP-3F-fileupload-jakarta-linkage.md):
  assinatura `javax.servlet` acionada pelo FileUpload 1.x no WildFly 41 e
  ponte transitória até a atividade 3.32.
- [`CP-3G-tiles-jsp-layout.md`](CP-3G-tiles-jsp-layout.md):
  substituição de Tiles por tag file e includes JSP protegidos.
- [`CP-3G-servlet-multipart.md`](CP-3G-servlet-multipart.md): substituição do
  Commons FileUpload pelo multipart nativo do Servlet/Jakarta.
- [`CP-3G-servlet-container-initializer.md`](CP-3G-servlet-container-initializer.md):
  substituição de Reflections pelo SCI padrão com JAR interno e fachada.
- [`CP-3F-oracle-jdbc17-module.md`](CP-3F-oracle-jdbc17-module.md):
  módulos Java SE exigidos pelo ojdbc17 no WildFly 41.
