# CP-3I — Aprovação do gate Java 21

## Escopo

O fechamento `3.45` aprova a mesma aplicação Jakarta no Java 21/WildFly 41
com os dois resultados exigidos: `portable-ci` em H2 e
`oracle-qualified` em Oracle Database 19c. Persistência JDBC, contratos HTTP,
XML, dependências, empacotamento, licenças, checksums e o roteiro de retorno
foram verificados nas atividades anteriores.

## Evidências aprovadas

- `persistence-ci-h2.json` e `persistence-oracle.json`: rollback, sequence,
  paginação, timestamp/timezone, CLOB, BLOB e limpeza;
- `contract-ci-h2.json` e `contract-oracle.json`: os 14 cenários do baseline
  mais `protectedFragments`, 15/15 em cada perfil;
- `manifest.properties`: runtime, licenças, checksums, WAR e dependências;
- `closure-{portable-ci,oracle-qualified}.json`: resumo sanitizado deste
  fechamento;
- `rollback.properties`: retorno não destrutivo ao CP-3H.

H2 não é tratado como prova de compatibilidade Oracle. A evidência Oracle foi
executada em rede autorizada e não contém URL, usuário, senha, wallet ou dados
permanentes.

## Integração e ausência de tag pública

O PR #28 deve ser integrado por squash com o assunto exato:

```text
checkpoint(CP-3I): approve Java 21 Jakarta gate
```

O CP-3I é um gate interno da fase 3. Portanto, não cria tag pública; as tags
continuam reservadas a `migration/01-legacy-baseline`,
`migration/02-java8-wildfly26` e `migration/03-final`.

## Rollback

O retorno seleciona o commit integrado do CP-3H registrado em
`rollback.properties`, reprovisiona Java 21/WildFly 41 do gate anterior e
restaura somente o WAR/configuração aprovados. Nenhum DDL, schema ou dado
permanente é removido. A aplicação real deve manter o procedimento blue/green
do runbook Java 17 como referência operacional.
