# CP-3C — Atualização do dom4j para 2.2.0

## Estado anterior

O fluxo mapeava o documento com `dom4j:dom4j:1.6.1`. Embora o reader já
recebesse configurações contra XXE, a biblioteca era antiga e a coordenada não
correspondia à linha atual publicada no Maven Central.

## Alteração

O POM usa `org.dom4j:dom4j:2.2.0`. A coordenada `org.dom4j` é parte da
alteração; manter `dom4j:dom4j` faria o Maven procurar um artefato inexistente.
Nenhuma dependência opcional do dom4j foi adicionada ao WAR.

O parser mantém o `XMLReader` seguro, o namespace do XSD e o mapeamento dos
campos. A validação XMLBeans continua sendo executada antes do mapeamento.

## Verificação

```bash
./scripts/validate-cp-3c-dom4j.sh --env .env
```

O contrato passa para o documento válido e rejeita XXE e expansão de
entidades. A allowlist do gate Java 17 contém `dom4j-2.2.0.jar`.

## Rollback

Reverter esta entrega restaura `dom4j:dom4j:1.6.1` sem alterar o XSD, os
documentos legítimos ou os dados persistidos. A remoção das APIs XML duplicadas
fica para a atividade 3.13.
