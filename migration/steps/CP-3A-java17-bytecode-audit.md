# INC-012 — Auditoria rejeita o bytecode Java 17

## Identificação

- checkpoint: `CP-3A`;
- estado verde de origem: `migration/02-java8-wildfly26`;
- alvo: bytecode Java 17, major `61`;
- etapa: `verification`;
- categoria: harness de verificação;
- reprodução: `natural`;
- perfis afetados: `portable-ci` e `oracle-qualified`.

## Tentativa antes da correção

Depois de liberar a política de toolchain, os 32 fontes compilaram e o Maven
empacotou o WAR com sucesso. A execução terminou com código `2` somente quando
o auditor recebeu o major `61`.

## Assinatura sanitizada

```text
FALHA: --expected-bytecode exige 51 ou 52
```

## Causa-raiz

`scripts/audit-legacy-war.sh` conhecia apenas os majors `51` e `52` das fases
Java 7 e Java 8. A rejeição não veio do compilador, da aplicação nem de uma
biblioteca.

## Menor correção

Adicionar major `61` à lista fechada aceita pelo auditor, preservando as
validações anteriores e sem relaxar a comparação do bytecode esperado.

## Teste de regressão

```bash
./scripts/build-cp-3a.sh --profile ci-h2 --env .env
./scripts/build-cp-2c.sh --profile ci-h2 --env .env
```

O primeiro comando exige major `61`; o segundo continua exigindo major `52` e
o checksum congelado da fase 2.

## Aplicação equivalente no sistema real

Revise validadores, plugins e ferramentas de análise que possuam listas
fechadas de versões de classe. Atualize somente o major esperado e mantenha a
falha rápida para qualquer versão não planejada.

## Rollback

Reverta a ampliação do auditor somente se o caminho Java 17 também for
removido. A seleção Java 7/8 permanece inalterada.
