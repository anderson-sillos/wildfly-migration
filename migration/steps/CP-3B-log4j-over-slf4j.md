# INC-008 / CP-3B — substituir Log4j 1 por ponte sobre o logging do WildFly

## Problema reproduzido

O WAR da fase 2 empacota `log4j-1.2.14.jar` e `log4j.properties`. No WildFly
26, o deployment ainda funciona, porém registra `WFLYLOG0100` porque a
configuração Log4j 1 dentro da aplicação está depreciada.

## Correção de menor impacto

1. Remover `log4j:log4j` do POM.
2. Adicionar `org.slf4j:log4j-over-slf4j:1.7.36`.
3. Declarar `org.slf4j:slf4j-api:1.7.36` como `provided`.
4. Excluir o módulo `org.apache.log4j` do WildFly no
   `jboss-deployment-structure.xml`, garantindo que a ponte local seja usada.
5. Remover `log4j.properties`.
6. Configurar categoria, formatter e MDC nos perfis `.cli` do WildFly.
7. Auditar o WAR para impedir Log4j 1, API SLF4J empacotada e backends
   concorrentes.
8. Exercitar logs funcionais, MDC e uma exceção completa em H2 e Oracle.

Os imports antigos permanecem deliberadamente nesta etapa. Isso representa a
estratégia aplicável a uma base real com muitos pontos de logging e separa a
retirada do componente EOL da reescrita das chamadas.

## Rollback

Voltar ao commit verde da atividade 3.6 restaura `log4j-1.2.14.jar`,
`log4j.properties` e a allowlist anterior. A correção não altera schema nem
dados persistentes.
