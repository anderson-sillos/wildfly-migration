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

Esta atividade não é o fechamento do CP-3I. Ainda falta a documentação de
reprodução do gate e a aprovação final do checkpoint. Os arquivos de evidência
são vinculados ao WAR e ao commit-fonte; não contêm segredos.

## Atividade 3.42 — contratos completos

Os 15 cenários foram executados novamente no WildFly 41/Java 21 com o mesmo
WAR nos dois perfis. Os 14 nomes e resultados do baseline legado permaneceram
`passed`; o cenário adicional `protectedFragments` também passou, confirmando
que fragmentos sob `WEB-INF` continuam protegidos.

- H2: [`contract-ci-h2.json`](../../migration/evidence/CP-3I/contract-ci-h2.json),
  `portable-ci`, 15/15;
- Oracle: [`contract-oracle.json`](../../migration/evidence/CP-3I/contract-oracle.json),
  `oracle-qualified`, 15/15;
- Runbook e comparação: [`CP-3I-contract-comparison.md`](../../migration/steps/CP-3I-contract-comparison.md).

O smoke remove os registros transitórios criados pela própria suíte. A
comparação não é teste de carga e não transforma H2 em substituto do Oracle.

## Atividade 3.43 — manifesto do gate

O manifesto [`manifest.properties`](../../migration/evidence/CP-3I/manifest.properties)
vincula o gate Java 21 ao commit, ao WAR, ao runtime Java 21/WildFly 41,
às licenças e checksums registrados em `runtime-manifest.tsv`, às dependências
finais e às evidências 3.41, 3.42 e CP-3H. O WAR foi contado e teve seu
SHA-256 calculado no momento da geração; drivers Oracle e H2 permanecem fora
do WAR.

O runbook [`CP-3I-manifest.md`](../../migration/steps/CP-3I-manifest.md)
descreve geração, validação, proveniência, proteção contra segredos e
rollback. O resultado `portable-ci` continua separado do `oracle-qualified`;
o manifesto apenas rastreia ambos os resultados já aprovados.

## Rollback

O rollback técnico retorna ao CP-3H por checkout do commit integrado anterior.
Os dados Oracle usados pelo probe são transitórios e foram removidos pelo
próprio relatório de limpeza; nenhum schema permanente é removido.
