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

## Decisão no CP-2B

Não trocar Log4j durante a atualização isolada do servidor. A proposta exige
preservar as bibliotecas legadas na fase 2 e atualizar logging isoladamente no
gate de dependências. O CP-2B apenas captura o aviso e verifica que não ocorre
erro de linkage.

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
