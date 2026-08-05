# CP-3J — fechamento do destino OpenJDK 25

## Escopo

O fechamento 3.50 aprova o mesmo WAR Jakarta no WildFly Community 41 com
OpenJDK 21 e OpenJDK 25. A trilha H2 é classificada como `portable-ci`; a
execução contra Oracle Database 19c recebe `oracle-qualified`. O fechamento
não cria uma quarta fase nem uma tag pública.

## Evidências

- `ci-h2-qualification.json` e `oracle-qualification.json`: agregadores
  sanitizados com 15/15 contratos nos dois JDKs;
- `ci-h2-java21-contracts.json`, `ci-h2-java25-contracts.json`,
  `oracle-java21-contracts.json` e `oracle-java25-contracts.json`: resultados
  individuais, checksums dos WARs e runtimes observados;
- `closure.properties`: decisão de integração e resumo dos gates;
- `rollback.properties`: retorno documentado ao gate CP-3I sem mutação de
  banco.

H2 não qualifica Oracle. O Oracle foi executado no schema descartável externo,
com credenciais fora do Git; os logs e relatórios não armazenam URL, usuário,
senha, wallet ou endereço interno.

## Integração

O PR #29 deve ser integrado por squash com o assunto exato:

```text
checkpoint(CP-3J): qualify OpenJDK 25
```

CP-3J é o último gate interno da fase 3 e não cria tag pública. A tag
`migration/03-final` pertence exclusivamente ao fechamento CP-3K.

## Rollback

O retorno seleciona o commit integrado do CP-3I registrado em
`rollback.properties`, reprovisiona OpenJDK 21/WildFly 41 e restaura o WAR e a
configuração aprovados naquele gate. O procedimento é blue/green e não remove
schema, usuário ou dados permanentes.
