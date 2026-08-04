# Evidência CP-3I — Semântica de persistência

## Atividade 3.41

O primeiro gate do CP-3I isolou os comportamentos JDBC que precisam de
qualificação além dos contratos HTTP. O mesmo probe foi executado com H2
2.4.240 em memória e com Oracle Database 19c usando `ojdbc17` 23.26.2.0.0.

| Verificação | `portable-ci` H2 | `oracle-qualified` | Evidência |
| --- | --- | --- | --- |
| Rollback | `passed` | `passed` | `persistence-*.json` |
| Sequence | `passed` | `passed` | `persistence-*.json` |
| Paginação | `passed` | `passed` | `persistence-*.json` |
| Timestamp/timezone | `passed` | `passed` | `persistence-*.json` |
| CLOB | `passed` | `passed` | `persistence-*.json` |
| BLOB | `passed` | `passed` | `persistence-*.json` |
| Limpeza | `passed` | `passed` | `persistence-*.json` |

As evidências estão separadas porque H2 demonstra a trilha portátil, mas não
substitui a validação do driver, do Oracle e de seus tipos/semânticas
específicas.

## Limites

Esta atividade não é o fechamento do CP-3I. Ainda faltam os contratos web
completos, comparação com o baseline, manifesto e documentação de reprodução
do gate. Os arquivos de evidência são vinculados ao WAR e ao commit-fonte;
não contêm segredos.

## Rollback

O rollback técnico retorna ao CP-3H por checkout do commit integrado anterior.
Os dados Oracle usados pelo probe são transitórios e foram removidos pelo
próprio relatório de limpeza; nenhum schema permanente é removido.
