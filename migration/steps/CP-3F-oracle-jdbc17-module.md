# INC-018/INC-019 / CP-3F — módulo ojdbc17 no WildFly 41

## Sintomas reproduzidos

Na primeira configuração do módulo Oracle no WildFly 41, o carregamento do
driver falhou porque `javax.management.InstanceAlreadyExistsException` não
estava visível ao módulo. Depois dessa correção, o primeiro teste de conexão
falhou porque `org.ietf.jgss.GSSException` também não estava visível.

## Correção

O template `runtime/phase3/java21-wildfly41/ojdbc17/module.xml.template` agora
declara explicitamente os módulos Java SE `java.management` e
`java.security.jgss`, além de `java.naming`, `java.sql` e
`java.transaction.xa`. O driver continua fora do WAR e é instalado somente no
módulo temporário do WildFly.

## Verificação

O smoke Oracle validou o datasource e concluiu os contratos HTTP completos no
Java 21/WildFly 41. O relatório é sanitizado e os registros `LAB-SMOKE-*` são
removidos pelo cleanup seguro ao final da execução.
