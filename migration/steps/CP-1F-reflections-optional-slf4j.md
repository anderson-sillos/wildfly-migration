# CP-1F — dependência opcional do Reflections no WildFly 9

## Situação observada

Reflections 0.9.10 referencia SLF4J, mas declara `slf4j-api` 1.6.1 como
opcional. A árvore Maven e a allowlist do WAR, portanto, não contêm um JAR
SLF4J.

No WildFly 9.0.2 a descoberta funcionou porque o subsistema de logging fornece
SLF4J implicitamente ao deployment. O WAR continua com 20 bibliotecas, mas o
fluxo não é independente do classloader do servidor.

## Decisão no baseline

Não empacotar outro backend. O smoke comprova no runtime real:

- o conjunto de validadores encontrado;
- a ordem determinística;
- a execução do pedido XML;
- a correlação presente no evento Log4j 1.

## Orientação para a migração real

Audite dependências opcionais e módulos implícitos antes de trocar o servidor.
No gate Java 17/WildFly 26, atualize Reflections para 0.10.2 e reexecute o
contrato legado. Depois da migração de namespace no Java 21/WildFly 41, use o
`ServletContainerInitializer` com `@HandlesTypes(Validator.class)` da atividade
`3.33` do `CP-3G` para substituir Reflections atrás de uma fachada própria, sem
biblioteca externa de descoberta. Remova também Log4j 1 e qualquer ponte
temporária na tarefa `3.34`.

## Rollback

Reverter a tarefa remove a descoberta e os eventos do fluxo, retornando à
importação XML validada no commit anterior.
