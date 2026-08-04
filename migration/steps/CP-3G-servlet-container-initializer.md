# CP-3G/3.33 — Descoberta de validadores com ServletContainerInitializer

## Problema e decisão

O gate Java 17 usava `org.reflections:reflections:0.10.2` para consultar
`getTypesAnnotatedWith(Validator.class)`. No destino Jakarta EE 11, essa
dependência é removida e a mesma extensibilidade passa a usar o mecanismo
portátil da especificação Servlet:

- `ValidatorServletContainerInitializer` declara
  `@HandlesTypes(Validator.class)`;
- `ValidatorDiscovery` filtra classes anotadas, concretas e compatíveis com
  `PedidoImportValidator`, instancia-as e ordena por `order()` e nome completo;
- o registro imutável fica como atributo do `ServletContext` do WAR;
- `LegacyPedidoXmlParser` depende somente da fachada e recebe o contexto web,
  sem conhecer a API de descoberta nem o WildFly.

O mecanismo é empacotado em
`WEB-INF/lib/wildfly-migration-validator-sci.jar`. Esse JAR contém a
annotation, o contrato, a fachada, a implementação do SCI e o descritor
`META-INF/services/jakarta.servlet.ServletContainerInitializer`. As
implementações concretas continuam em `WEB-INF/classes` e podem também ser
fornecidas por outros JARs aprovados da aplicação.

O JAR separado é intencional: a JAR Services API procura o descritor de
implementação do SCI dentro de um JAR. Assim o registro não depende de VFS,
TCCL ou de uma API específica do WildFly e continua associado ao
`ServletContext` de cada módulo web, inclusive quando o WAR é implantado em
um EAR.

## Verificação

Build e auditoria estrutural:

```bash
./scripts/build-cp-3f-jakarta.sh --env .env
./scripts/validate-cp-3g-discovery.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war
```

O smoke do WildFly 41 valida também a execução real do SCI e exige no log
sanitizado os marcadores `validator_sci_discovery` e
`legacy_validator_order=numero-formato,valor-monetario,status-inicial`. O
mesmo contrato HTTP continua rejeitando um XML com status diferente de
`NOVO`, comprovando que os validadores são instanciados antes do uso pelo
fluxo de importação.

A auditoria falha se Reflections, `LegacyValidatorDiscovery`, o descritor de
serviço duplicado em `WEB-INF/classes` ou qualquer uma das quatro classes de
infraestrutura reaparecer fora do JAR interno. O JAR é inspecionado sem
permitir APIs Servlet empacotadas no WAR.

## Rollback

O retorno desta atividade é o commit verde integrado do CP-3F, que ainda
contém o mecanismo Jakarta anterior e a ponte Reflections. Não remova a
configuração de logging nem inicie a atividade 3.34 neste rollback; a retirada
da ponte Log4j e a configuração explícita `logImpl=SLF4J` permanecem separadas.
