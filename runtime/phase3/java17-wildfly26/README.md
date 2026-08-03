# Gate Java 17 no WildFly 26

Esta configuração materializa a atividade 3.4 sem criar uma nova fase pública:

| Componente | Versão fixa |
| --- | --- |
| Java | Eclipse Temurin OpenJDK 17.0.20+8 |
| WildFly comunitário | 26.1.3.Final |
| Maven | 3.9.16 |
| H2 de teste | 2.4.240 |
| API web | Jakarta EE 8, ainda em pacotes `javax.*` |
| Logging | SLF4J 1.7.36 do servidor/JBoss LogManager |
| Upload transitório | Commons FileUpload 1.6.0 / Commons IO 2.19.0 |
| Descoberta transitória | Reflections 0.10.2 |

O [manifesto](runtime-manifest.tsv) registra origem, licença e SHA-256. O
WildFly 26 é um runtime de transição EOL e não representa o destino final.

O H2 2.4.240 é infraestrutura exclusiva do perfil `ci-h2`: o JAR permanece
fora do WAR, é provisionado como módulo do WildFly e usa somente uma URL
`jdbc:h2:mem:` sem console ou listener. O H2 1.4.200 continua registrado no
runtime histórico e no cache único para que as tags anteriores permaneçam
reproduzíveis.

O perfil `oracle` continua separado e usa o módulo externo `com.oracle.ojdbc17`.
O JAR é fornecido por `OJDBC17_JAR` e validado por SHA-256; nenhuma aprovação
H2 pode ser promovida a `oracle-qualified`.

Os perfis configuram categoria e MDC no subsistema de logging. O WAR contém
temporariamente `log4j-over-slf4j` 1.7.36 para preservar os imports antigos,
mas não empacota Log4j 1, `slf4j-api` nem backend próprio.

O WAR mantém temporariamente a API `javax` do Commons FileUpload 1.x. As
versões 1.6.0 do parser e 2.19.0 do Commons IO ficam explícitas na allowlist;
a substituição por Servlet `Part` no namespace `jakarta` pertence à atividade
3.32.

A descoberta anotada usa Reflections 0.10.2 somente como ponte. O WAR inclui
Javassist 3.28.0-GA e JSR-305 3.0.2, não inclui Guava 15, FindBugs annotations
2.0.1 nem SLF4J próprio, e resolve `@Validator` pelo ModuleClassLoader do WAR.
