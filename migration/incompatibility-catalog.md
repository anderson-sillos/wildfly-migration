# Catálogo de incompatibilidades

Esta página é a visualização humana do catálogo estruturado. Os arquivos TSV
continuam sendo a fonte de dados versionada e validada pelo CI:

- [`incompatibilities.tsv`](incompatibilities.tsv): uma linha por incompatibilidade;
- [`incompatibility-fixtures.tsv`](incompatibility-fixtures.tsv): fixtures
  complementares, sempre opt-in;
- [`incompatibility-template.md`](incompatibility-template.md): modelo para o
  registro detalhado de cada cenário.

## Incompatibilidades catalogadas

Cada linha aponta para o registro detalhado na coluna **Registro**. A coluna
**Reprodução** informa se a falha foi observada naturalmente ao executar o
estado verde anterior ou se exige uma fixture explícita.

| ID | CP | Origem → destino | Etapa | Categoria | Reprodução | Estado | Registro |
| --- | --- | --- | --- | --- | --- | --- | --- |
| INC-001 | CP-1C | Java 7u80/Maven 3.8.9 → Maven Central atual | compilation | environment | natural | resolved | [CP-1C](steps/CP-1C-legacy-build-https.md) |
| INC-002 | CP-1F | Commons FileUpload 1.2.2 → WAR sem a biblioteca no WildFly 9 | execution | dependency | natural | resolved | [CP-1F](steps/CP-1F-commons-fileupload-commons-io.md) |
| INC-003 | CP-1F | XMLBeans 2.3.0/XSD → padrão JAXP compatível | execution | library | natural | resolved | [CP-1F](steps/CP-1F-xmlbeans-xsd-regex.md) |
| INC-004 | CP-1G | ojdbc7/DatabaseMetaData → Oracle 19c RU 19.3 | execution | observability | natural | resolved | [CP-1G](steps/CP-1G-oracle-ru-detection.md) |
| INC-005 | CP-2A | Java 7/Maven Enforcer → Temurin 8u492 | compilation | toolchain-policy | natural | resolved | [CP-2A](steps/CP-2A-java8-toolchain.md) |
| INC-006 | CP-2A | WildFly 9/Java 7/JAVA_OPTS → Temurin 8u492 | execution | runtime-configuration | natural | resolved | [CP-2A](steps/CP-2A-wildfly9-max-perm-size.md) |
| INC-007 | CP-2B | Java 8/WildFly 9/configuração → Java 8/WildFly 26 padrão | deployment | datasource-configuration | natural | resolved | [CP-2B](steps/CP-2B-wildfly26-missing-datasource.md) |
| INC-008 | CP-2B | Configuração Log4j 1 no deployment → subsistema de logging WildFly 26 | deployment | logging | natural | resolved | [CP-3B](steps/CP-3B-log4j-over-slf4j.md) |
| INC-009 | CP-2B | HTTP loopback WildFly 9 → HTTPS/keystore padrão WildFly 26 | startup | security-configuration | natural | resolved | [CP-2B](steps/CP-2B-wildfly26-default-https.md) |
| INC-010 | CP-2B | CLI datasource WildFly 9 → modelo de datasource WildFly 26 | configuration | management-model | natural | resolved | [CP-2B](steps/CP-2B-wildfly26-pool-name.md) |
| INC-011 | CP-3A | Java 8/Maven Enforcer → Temurin 17.0.20 | compilation | toolchain-policy | natural | resolved | [CP-3A](steps/CP-3A-java17-toolchain.md) |
| INC-012 | CP-3A | Bytecode major 51/52 → Java 17 major 61 | verification | verification-harness | natural | resolved | [CP-3A](steps/CP-3A-java17-bytecode-audit.md) |
| INC-013 | CP-3A | H2 1.4.200/check-in → H2 2.4.240/múltiplas conexões | execution | portable-sql-harness | natural | resolved | [CP-3A](steps/CP-3A-h2-2-check-constraint.md) |
| INC-014 | CP-3C | ojdbc7/Java 17 → ojdbc17 23.26.2.0.0 | execution | dependency | natural | resolved | [CP-3C](steps/CP-3C-ojdbc17.md) |
| INC-015 | CP-3E | WAR EE 8/javax → módulos Jakarta do WildFly 41 | deployment | namespace-classloader | natural | observed | [CP-3E](steps/CP-3E-wildfly41-entry.md) |
| INC-016 | CP-3F | Tiles 2.1.4/javax/TLD 2.0 → módulos Jakarta do WildFly 41 | deployment | namespace-classloader | natural | resolved | [CP-3G](steps/CP-3G-tiles-jsp-layout.md) |
| INC-017 | CP-3F | Commons FileUpload 1.6.0/assinaturas javax → Servlet Jakarta 6.1 | execution | dependency | natural | observed | [CP-3F](steps/CP-3F-fileupload-jakarta-linkage.md) |
| INC-018 | CP-3F | OJDBC17/Java 21 module → classloader WildFly 41 | deployment | classloader | natural | resolved | [CP-3F](steps/CP-3F-oracle-jdbc17-module.md) |
| INC-019 | CP-3F | OJDBC17/JGSS module → datasource WildFly 41 | execution | classloader | natural | resolved | [CP-3F](steps/CP-3F-oracle-jdbc17-module.md) |
| INC-020 | CP-3G | Commons FileUpload 1.x → Servlet Part Jakarta | execution | dependency | natural | resolved | [CP-3G](steps/CP-3G-servlet-multipart.md) |
| INC-021 | CP-3G | Reflections 0.10.2 → ServletContainerInitializer/HandlesTypes | startup | class-discovery | natural | resolved | [CP-3G](steps/CP-3G-servlet-container-initializer.md) |
| INC-022 | CP-1F | XSD válido/domínio inválido → rejeição pelo validador XML | execution | validation | fixture-opt-in | resolved | [CP-1F](steps/CP-1F-validator-after-xsd.md) |
| INC-023 | CP-3H | Entidade XML externa → parser XML seguro | execution | security | fixture-opt-in | resolved | [CP-3H](steps/CP-3H-xml-safe.md) |
| INC-024 | CP-3J | javac 25/source-target → maven-compiler/release 21 | compilation | toolchain-policy | natural | resolved | [CP-3J](steps/CP-3J-java25-toolchain.md) |
| INC-025 | CP-3B | MyBatis 3.4.5 → MyBatis 3.5.19 | execution | dependency | natural | resolved | [CP-3B](steps/CP-3B-mybatis-3.5.19.md) |
| INC-026 | CP-3C | xml-apis 1.3.02/Geronimo StAX 1.0 → módulo java.xml | execution | duplicate-api | natural | resolved | [CP-3C](steps/CP-3C-java-xml-apis.md) |
| INC-027 | CP-3C | dom4j 1.6.1 → dom4j 2.2.0 | execution | library | natural | resolved | [CP-3C](steps/CP-3C-dom4j-2.2.0.md) |

## Fixtures complementares

Fixtures não fazem parte do fluxo funcional padrão. Cada uma deve ser
executada explicitamente, permanecer com `enabled_by_default=false` e apontar
para uma incompatibilidade já registrada no catálogo principal.

| ID | Incompatibilidade | Fixture | Finalidade | Motivo do opt-in | Registro |
| --- | --- | --- | --- | --- | --- |
| FIX-001 | INC-022 | [`pedido-invalido-validador.xml`](../contract-tests/fixtures/xml/pedido-invalido-validador.xml) | XSD válido rejeitado pela validação de domínio | Dados reais não produzem uma falha de domínio determinística | [CP-1F](steps/CP-1F-validator-after-xsd.md) |
| FIX-002 | INC-023 | [`pedido-xxe.xml`](../contract-tests/fixtures/xml/pedido-xxe.xml) | Rejeição de DOCTYPE e entidade externa | Rede e resolução externa devem permanecer desabilitadas | [CP-3H](steps/CP-3H-xml-safe.md) |

## Como consultar

Para a tabela legível por máquina:

```bash
column -t -s $'\t' migration/incompatibilities.tsv | less -S
column -t -s $'\t' migration/incompatibility-fixtures.tsv | less -S
```

Para validar estrutura, referências, IDs, fixtures, cobertura mínima e
ausência de segredos:

```bash
./scripts/validate-incompatibility-catalog.sh
```

O validador do CI considera os TSVs a fonte canônica; esta página Markdown é
uma visão de consulta e deve ser mantida sincronizada com eles.
