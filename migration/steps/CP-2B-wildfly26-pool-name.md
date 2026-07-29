# INC-010 — WildFly 26 rejeita `pool-name` na criação do datasource

## Identificação

- checkpoint: `CP-2B`;
- origem: CLI de datasource aprovada no WildFly 9;
- destino: modelo de gerenciamento do WildFly 26.1.3.Final;
- etapa: `configuration`;
- categoria: management model;
- reprodução: natural durante a primeira aplicação do perfil H2;
- estado: resolvido.

## Assinatura sanitizada

```text
CommandFormatException:
'pool-name' is not found among the supported properties
```

## Causa-raiz

No modelo do WildFly 26, o endereço
`/subsystem=datasources/data-source=MigrationDS` já fornece o nome do pool. A
operação `add` não expõe mais o atributo redundante `pool-name` aceito pela
CLI histórica.

## Menor correção

Criar arquivos de perfil específicos para WildFly 26 e remover somente o
argumento `pool-name`. JNDI, driver, URL, validação, transação e limites do
pool permanecem iguais aos valores aprovados no WildFly 9.

## Teste de regressão

O perfil deve ser aplicado em uma cópia temporária limpa e
`test-connection-in-pool` deve retornar sucesso. O datasource resultante deve
continuar registrado como `MigrationDS` e publicar
`java:/jdbc/MigrationDS`.

## Aplicação equivalente no sistema real

Não copie scripts CLI entre versões sem consultar o modelo do destino. Use
`read-operation-description(name=add)` para comparar atributos e mantenha
arquivos versionados por linha do servidor quando o modelo divergir.

## Rollback

Descarte a cópia temporária. Os perfis do WildFly 9 permanecem imutáveis em
`runtime/legacy/profiles/`.
