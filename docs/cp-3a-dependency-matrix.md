# CP-3A — Matriz de modernização das dependências

Esta matriz encerra a análise da atividade 3.3. Ela parte da árvore realmente
empacotada na fase 2 e define o candidato que cada atividade posterior deve
testar. Nenhuma versão desta página é aplicada antecipadamente ao POM: cada
troca continuará isolada em seu checkpoint, com tentativa, contratos,
auditoria e rollback próprios.

## Como interpretar

- **Java 17** indica se o candidato pode ser executado nessa JVM segundo os
  requisitos publicados pelo projeto. Para componentes descontinuados, a
  evidência do laboratório é identificada separadamente e não vira declaração
  de suporte do fornecedor.
- **EE 8/`javax`** indica se o candidato preserva o gate atual no WildFly
  26.1.3.Final. “Neutro” significa que a biblioteca não depende do namespace
  Java/Jakarta EE.
- **Impacto** estima a mudança na aplicação: baixo para substituição
  transparente, médio quando exige configuração ou reteste dirigido e alto
  quando altera API, classloader, artefatos gerados ou arquitetura.
- Uma versão candidata é uma decisão reproduzível para este plano, não uma
  autorização automática para produção. Vulnerabilidades, licenças e
  compatibilidade da aplicação real ainda passam pelos gates correspondentes.

## Dependências diretas e componentes fornecidos

| Componente na fase 2 | Candidato definido | Java 17 | EE 8/`javax` | Impacto e decisão |
| --- | --- | --- | --- | --- |
| APIs históricas Servlet 2.4, JSP 2.0 e JSTL 1.2 | `jakarta.platform:jakarta.jakartaee-web-api:8.0.0`, já adotada em `provided` | Sim | Sim; Jakarta EE 8 ainda expõe `javax.*` | **Baixo.** Manter a API agregada e fora de `WEB-INF/lib` até a migração de namespace do CP-3E. O descritor TLD 2.0 não é uma dependência Maven. |
| `org.mybatis:mybatis:3.4.5` | `org.mybatis:mybatis:3.5.19` | Sim; requer Java 8 ou superior | Neutro | **Médio.** Atualizar em 3.6 e testar mappers, aliases, type handlers, reflexão e transações em H2 e Oracle. Observar a seleção automática de logging; em 3.34 fixar `logImpl=SLF4J` para não depender da ordem de descoberta. |
| `log4j:log4j:1.2.14` | logging do WildFly/JBoss LogManager via SLF4J; `org.slf4j:log4j-over-slf4j:1.7.36` somente como ponte temporária | Sim para a ponte; a linha SLF4J 1.7 está inativa | Neutro | **Alto.** Log4j 1 está EOL desde 2015 e deve sair em 3.7. Se imports `org.apache.log4j` impedirem a troca direta, usar a ponte sem backend concorrente no WAR, tratar `slf4j-api` como fornecida pelo servidor e validar MDC, categorias, exceções e `server.log`. Remover a ponte em 3.34. |
| `commons-fileupload:commons-fileupload:1.2.2` | `commons-fileupload:commons-fileupload:1.6.0` | Sim; requer Java 8 ou superior | Sim; a linha 1.x usa Servlet `javax` | **Médio.** Atualizar em 3.8, preservar limites, normalização, temporários e contrato HTTP. É a última linha estável 1.x escolhida para o gate `javax`; a remoção arquitetural ocorrerá em 3.32 com Servlet multipart nativo. |
| `commons-io:commons-io:1.3.2` | `commons-io:commons-io:2.19.0`, versão requerida pelo FileUpload 1.6.0 | Sim | Neutro | **Médio.** Atualizar junto de 3.8 e manter a dependência explícita para que o WAR não volte a depender de resolução opcional ou do servidor. |
| `org.reflections:reflections:0.9.10` | `org.reflections:reflections:0.10.2` | Sim; bytecode Java 8 | Neutro | **Alto.** Atualizar em 3.9 e comparar conjunto e ordem de `getTypesAnnotatedWith(Validator.class)` no classloader real do WildFly. A linha 0.10 altera scanners e transitivas e possui relatos de diferenças de descoberta; ela é uma ponte até a substituição pelo SCI padrão `ServletContainerInitializer` em 3.33. |
| `org.apache.tiles:tiles-api:2.1.4` e `tiles-jsp:2.1.4` | manter exatamente `2.1.4` como exceção temporária | Execução comprovada no laboratório; sem suporte ativo | Sim; usa APIs `javax` | **Alto.** O Apache Tiles está descontinuado e atualizar para outra versão também EOL não resolve o risco. Preservar em 3.16 somente para reduzir impacto no gate Java 17 e substituir por JSP tag files/includes em 3.31. |
| `org.apache.xmlbeans:xmlbeans:2.3.0` | `org.apache.xmlbeans:xmlbeans:5.3.0` | Sim; requer Java 8 ou superior | Neutro | **Alto.** Atualizar e regenerar os tipos a partir do XSD em 3.11; comparar serialização, namespaces e validação. A API Log4j 2 introduzida transitivamente não é um backend e exige auditoria de integração com o logging do servidor. |
| `dom4j:dom4j:1.6.1` | `org.dom4j:dom4j:2.2.0` | Sim; requer Java 11 | Neutro | **Alto.** A coordenada muda. Atualizar em 3.12, configurar o parser seguro e executar casos legítimos, XXE e expansão de entidades. Não habilitar transitivas opcionais sem uso comprovado. |
| `xml-apis:xml-apis:1.3.02` | remover | Sim, por meio do módulo `java.xml` do JDK | Neutro | **Médio.** Remover em 3.13 e provar que DOM, SAX e JAXP são resolvidos pelo Java 17, evitando duplicação de APIs no WAR. |
| `org.apache.geronimo.specs:geronimo-stax-api_1.0_spec:1.0` | remover | Sim, por meio do módulo `java.xml` do JDK | Neutro | **Médio.** Remover em 3.13 junto de `stax-api:1.0.1` e comprovar a resolução de `javax.xml.stream` pelo Java 17. |
| módulo externo `com.oracle:ojdbc7` | módulo externo `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` | Sim; certificado para JDK 17 | Neutro; JDBC é Java SE | **Alto.** Trocar em 3.14, sem incluir o driver no WAR, e qualificar contra Oracle 19c: conexão, transações, timestamps e LOBs. Reprovisionar o mesmo driver no runtime final em 3.37. |

## Resultado esperado para as transitivas

Esta tabela não tenta prever apenas a contagem final. Ela registra a origem da
mudança para que a auditoria posterior detecte tanto bibliotecas antigas que
sobraram quanto exclusões indevidas.

| Transitiva da fase 2 | Resultado candidato | Motivo e verificação |
| --- | --- | --- |
| `com.google.guava:guava:15.0` | remover | Reflections 0.10.2 não a declara. Confirmar ausência após 3.9. |
| `org.javassist:javassist:3.19.0-GA` | atualizar para `3.28.0-GA` | É transitiva obrigatória do Reflections 0.10.2. O MyBatis 3.5.19 incorpora e realoca internamente sua própria cópia, portanto ela não deve gerar um segundo JAR Maven. |
| `com.google.code.findbugs:annotations:2.0.1` | substituir por `com.google.code.findbugs:jsr305:3.0.2` | Mudança transitiva do Reflections 0.10.2; auditar licença e ausência do artefato antigo. |
| `org.slf4j:slf4j-api:1.7.32` trazida por Reflections e `1.7.36` requerida pela ponte | convergir para a API fornecida pelo WildFly | Excluir a cópia empacotada ou declará-la em `provided`; validar a versão efetiva e não incluir binding/backend concorrente no WAR. |
| `org.apache.logging.log4j:log4j-api:2.24.2` | manter somente se requerida pelo XMLBeans 5.3.0 | É API, não backend. Confirmar a integração do classloader e impedir `log4j-core` no WAR. |
| `stax:stax-api:1.0.1` | remover | Deixa de vir com XMLBeans 5.3.0 e a API StAX já existe no módulo `java.xml`. |
| `commons-logging-api:1.1`, `tiles-core:2.1.4`, `tiles-servlet:2.1.4`, `commons-digester:1.8.1` e `commons-beanutils:1.8.0` | manter temporariamente | Permanecem ligados ao Tiles 2.1.4 no gate Java 17; todo o conjunto deve desaparecer na substituição de 3.31. |
| transitivas opcionais de MyBatis, dom4j e Reflections | não empacotar sem uso comprovado | OGNL/Javassist do MyBatis são realocados; Jaxen, JAXB, Gson, dom4j e parsers opcionais não entram automaticamente. A árvore Maven deve justificar qualquer exceção. |

## Sequência aprovada

As decisões ficam distribuídas para limitar o risco e tornar cada entrega
reversível:

1. CP-3B atualiza MyBatis, logging, FileUpload/Commons IO e Reflections.
2. CP-3C atualiza XMLBeans e dom4j, remove APIs XML duplicadas e troca o módulo
   Oracle.
3. CP-3D congela e audita o gate Java 17, mantendo Tiles como única exceção
   web deliberada.
4. CP-3G remove Tiles, FileUpload, Reflections e a ponte de Log4j; o CP-3H
   fixa novamente as versões e o empacotamento no runtime final.

O rollback de uma atualização restaura somente o grupo alterado e reexecuta o
último manifesto aprovado. Não se deve avançar para o grupo seguinte enquanto
H2, Oracle quando aplicável, contratos e auditoria do grupo atual não estiverem
aprovados.

## Fontes primárias consultadas

Consulta realizada em 30/07/2026:

- [Jakarta EE 8 Platform](https://jakarta.ee/specifications/platform/8/);
- [MyBatis 3.5.19 — dependências e requisito Java 8](https://repo.maven.apache.org/maven2/org/mybatis/mybatis/3.5.19/mybatis-3.5.19.pom);
- [Apache Commons FileUpload — histórico de versões](https://commons.apache.org/proper/commons-fileupload/changes.html) e [POM 1.6.0](https://repo.maven.apache.org/maven2/commons-fileupload/commons-fileupload/1.6.0/commons-fileupload-1.6.0.pom);
- [Reflections 0.10.2 — POM](https://repo.maven.apache.org/maven2/org/reflections/reflections/0.10.2/reflections-0.10.2.pom) e [relato de descoberta no 0.10.2](https://github.com/ronmamo/reflections/issues/373);
- [Log4j 1 — estado EOL](https://logging.apache.org/log4j/1.x/) e [ponte Log4j sobre SLF4J](https://www.slf4j.org/legacy.html);
- [Apache Tiles no Attic](https://attic.apache.org/projects/tiles.html);
- [Apache XMLBeans 5.3.0](https://xmlbeans.apache.org/download/) e [POM 5.3.0](https://repo.maven.apache.org/maven2/org/apache/xmlbeans/xmlbeans/5.3.0/xmlbeans-5.3.0.pom);
- [dom4j 2.2.0 — POM](https://repo.maven.apache.org/maven2/org/dom4j/dom4j/2.2.0/dom4j-2.2.0.pom);
- [Java 17 — módulo `java.xml`](https://docs.oracle.com/en/java/javase/17/docs/api/java.xml/module-summary.html);
- [Oracle JDBC — downloads e interoperabilidade](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html) e [POM do `ojdbc17` 23.26.2.0.0](https://repo.maven.apache.org/maven2/com/oracle/database/jdbc/ojdbc17/23.26.2.0.0/ojdbc17-23.26.2.0.0.pom).
