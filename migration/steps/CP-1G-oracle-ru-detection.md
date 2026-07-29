# CP-1G — detecção do Release Update do Oracle

## Tentativa antes da correção

O primeiro fechamento do baseline tentou exigir `19.3.0.0.0` diretamente em
`DatabaseMetaData.getDatabaseProductVersion()`. A conexão, o produto Oracle 19c
e o schema estavam válidos, mas `oracle-lab-schema.sh verify` rejeitou a
qualificação com:

```text
Oracle Database RU diverge de 19.3.0.0.0
```

## Causa-raiz

A metadata JDBC identifica a família e a release do produto, mas a forma do
texto retornado pelo `ojdbc7` não é um contrato confiável para localizar o
Release Update completo. O RU já havia sido confirmado no banco como
`19.3.0.0.0`; a falha estava no mecanismo de captura da evidência.

## Menor correção

O verificador mantém duas provas independentes:

1. `DatabaseMetaData` deve identificar `Oracle Database 19c`;
2. `PRODUCT_COMPONENT_VERSION.VERSION_FULL` deve retornar exatamente
   `19.3.0.0.0` para o produto Oracle Database.

Nenhuma permissão adicional, URL, identidade ou credencial é registrada.

## Teste de regressão

```bash
./scripts/oracle-lab-schema.sh verify --env .env
```

O comando continua validando privilégios mínimos, escopo dos objetos, seed e
valores persistidos depois de confirmar produto e RU.

## Aplicação equivalente no sistema real

Não deduza o patch efetivo somente pelo nome do driver ou pela primeira linha
da metadata JDBC. Capture separadamente versão do servidor, RU, versão da JVM,
driver e servidor de aplicação, usando uma view de catálogo autorizada e
sanitizando a evidência.

## Rollback

Reverter esta correção restaura o falso negativo da metadata, sem alterar
schema ou dados. Não remova a validação do RU para contornar a falha.
