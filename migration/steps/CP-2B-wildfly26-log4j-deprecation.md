# INC-008 — WildFly 26 deprecia a configuração Log4j 1 do deployment

## Identificação

- checkpoint: `CP-2B`;
- origem: Log4j 1.2.14 e `WEB-INF/classes/log4j.properties`;
- destino: subsistema de logging do WildFly 26.1.3.Final;
- etapa: `deployment`;
- categoria: logging;
- reprodução: `natural`;
- estado: adiado para o gate `CP-3B`.

## Assinatura sanitizada

```text
WFLYLOG0100: Usage of a log4j configuration file was found in deployment.
Support for log4j configuration files in deployments has been deprecated.
```

## Causa-raiz

O WildFly 26 detecta e ainda aceita o arquivo histórico do deployment, mas
avisa que esse caminho será removido em uma versão futura. O aviso confirma
uma dívida de compatibilidade; ele não foi a causa da falha do deployment.

## Alternativa de correção sem trocar a biblioteca

É possível manter `log4j:log4j:1.2.14` e retirar
`WEB-INF/classes/log4j.properties` do WAR. A configuração equivalente passa
para o subsistema de logging do WildFly, idealmente em um `logging-profile`
dedicado à aplicação, com handlers e categorias provisionados por CLI.

Essa alternativa preserva as chamadas `org.apache.log4j.Logger` e a versão da
biblioteca enquanto separa configuração operacional do artefato. O
laboratório deve comprovar antes de adotá-la:

1. que o JAR e a árvore Maven permanecem inalterados;
2. que `log4j.properties` não aparece no WAR;
3. que o runtime produz nível, destino, padrão e correlação equivalentes;
4. que `WFLYLOG0100` desaparece;
5. que não ocorre conflito entre a dependência empacotada e a integração de
   logging fornecida pelo servidor.

O guia oficial do WildFly 26 recomenda o subsistema para configuração
administrável em runtime e documenta a configuração por deployment como um
arquivo dentro do próprio artefato:
<https://docs.wildfly.org/26/Admin_Guide.html#Logging>.

Uma propriedade como `-Dlog4j.configuration=file:...` seria uma segunda
alternativa literal para manter um arquivo externo, mas normalmente exige
assumir o Log4j empacotado como implementação própria, desabilitar a
configuração automática do deployment e controlar explicitamente as
dependências de logging. Por aumentar o risco de classloader, ela não é a
opção preferida para o CP-2B.

## Decisão atual no CP-2B

Não trocar Log4j durante a atualização isolada do servidor. A alternativa de
externalização acima será testada separadamente depois que o datasource
estiver verde; até essa prova, o CP-2B apenas captura o aviso e verifica que
não ocorre erro de linkage.

## Correção planejada

O `CP-3B` removerá `log4j:log4j` e adotará logging mantido com a ponte
temporária estritamente necessária. O gate Jakarta removerá qualquer ponte
restante.

## Teste de regressão

Depois do datasource ativo, os contratos deverão comprovar logs da aplicação
e correlação sem `ClassNotFoundException`, `NoClassDefFoundError` ou
`LinkageError`. A auditoria continuará mostrando a dependência histórica até
o gate explicitamente responsável por removê-la.

## Rollback

Nenhuma correção foi aplicada no CP-2B. O rollback continua sendo o commit
verde do CP-2A.
