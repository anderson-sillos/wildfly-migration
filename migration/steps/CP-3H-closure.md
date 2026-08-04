# CP-3H — Fechamento do Oracle e do empacotamento

## Objetivo

O encerramento da atividade `3.40` consolida as validações realizadas nos
gates `3.36` a `3.39`. O mesmo WAR Jakarta é verificado no perfil portátil H2
(`portable-ci`) e, em ambiente autorizado, no Oracle 19c
(`oracle-qualified`). XML seguro, módulos de datasource, dependências e
empacotamento são gates independentes; o resultado de H2 não substitui a
qualificação Oracle.

## Execução

Com o runtime Java 21/WildFly 41, o WAR já construído e um `.env` externo:

```bash
./scripts/smoke-wildfly41-datasource.sh \
  --profile ci-h2 --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war

./scripts/qualify-cp-3h-oracle.sh \
  --env .env \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --non-interactive

./scripts/validate-cp-3h-closure.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war
```

O primeiro comando executa os 15 cenários HTTP com H2 em memória. O segundo
executa a mesma suíte e a qualificação específica do Oracle 19c, incluindo a
versão completa do banco, o driver `ojdbc17`, o JVM e o WildFly observados.
Nenhum comando imprime a URL, usuário, senha ou wallet do Oracle.

Para a validação estática feita antes da montagem do WAR no CI hospedado, use:

```bash
./scripts/validate-cp-3h-closure.sh --skip-war
```

Nesse modo, as evidências versionadas, fontes, POM e configuração são
validados, mas não se tenta calcular o checksum de um WAR que ainda não foi
construído.

## Evidências

As duas qualificações finais são deliberadamente separadas:

- `migration/evidence/CP-3H/closure-portable-ci.json` — H2, 15/15 cenários;
- `migration/evidence/CP-3H/closure-oracle-qualified.json` — Oracle 19c,
  15/15 cenários;
- `migration/evidence/CP-3H/closure.properties` — resumo dos gates;
- `migration/evidence/CP-3H/rollback.properties` — retorno verificável ao
  CP-3G.

Os relatórios carregam o commit-fonte, o checksum do WAR e
`workingTree=false`. A evidência Oracle permanece sanitizada e não contém
segredos ou endereços internos.

## Rollback

O rollback retorna ao commit integrado do CP-3G indicado em
`rollback.properties`, usando o WAR e o runtime aprovados naquele checkpoint.
É uma reversão de código, configuração e artefato; a atividade não executa
DDL, não remove schema e não altera dados Oracle. Se o Oracle estiver
indisponível, a qualificação é marcada como não executada e o fechamento não
é considerado verde.

## Reprodução

Em um checkout limpo, siga a preparação do runtime Java 21/WildFly 41, forneça
os arquivos externos indicados no `.env.example`, construa o perfil
`cp-3e-jakarta11` e execute o gate acima. O CI hospedado reproduz a trilha H2;
o comando Oracle deve ser executado somente na rede interna autorizada.
