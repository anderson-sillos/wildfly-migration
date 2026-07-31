# CP-3B — Dependências centrais

O CP-3B moderniza uma dependência por atividade sobre o runtime já aprovado
no CP-3A: Java 17, WildFly 26.1.3, Maven 3.9.16, Jakarta EE 8 com pacotes
`javax.*` e H2 2.4.240 no perfil portátil. O Oracle 19c permanece uma trilha
separada.

## Atividade 3.6 — MyBatis 3.5.19

A primeira alteração troca somente `org.mybatis:mybatis:3.4.5` por
`org.mybatis:mybatis:3.5.19`. Log4j, Commons FileUpload e Reflections mantêm as
versões do CP-3A para que seus efeitos sejam avaliados nas atividades 3.7,
3.8 e 3.9.

O gate Java 17 possui sua própria allowlist de `WEB-INF/lib`. Assim, a
allowlist imutável da fase 2 continua exigindo `mybatis-3.4.5.jar`, enquanto o
build ativo exige exatamente `mybatis-3.5.19.jar`. O MyBatis 3.5.19 não
introduz outro JAR Maven no WAR: suas cópias internas necessárias de OGNL e
Javassist são realocadas dentro do próprio artefato.

### Qualificação H2

```bash
./scripts/qualify-cp-3b-h2.sh --env .env
```

O comando executa `doctor` para CP-3B, build e auditoria do WAR, lifecycle H2,
sonda MyBatis e os 14 contratos HTTP. Ele produz:

- `app/target/contract-results/cp-3b-mybatis-ci-h2.json`;
- `app/target/contract-results/cp-3b-ci-h2.json`.

Esse resultado é `portable-ci` e não comprova compatibilidade Oracle.

### Qualificação Oracle

Depois da trilha H2, em uma máquina com acesso autorizado ao schema
descartável:

```bash
./scripts/qualify-cp-3b-oracle.sh --env .env
```

O comando reconstrói o mesmo WAR no perfil Oracle, executa os 14 contratos,
valida mappers, aliases, type handlers, reflexão, commit, rollback,
`TIMESTAMP(6)` e BLOB e remove somente registros transitórios
`LAB-SMOKE-*`. Ele produz:

- `app/target/contract-results/cp-3b-mybatis-oracle.json`;
- `app/target/contract-results/cp-3b-oracle.json`.

Os relatórios não contêm URL, usuário ou senha. O resultado Oracle é
`oracle-qualified`.

## Rollback

Durante o CP-3B, o último checkpoint verde é o commit de entrega do CP-3A:

```bash
git switch --detach 6d94e5fc735575fa2ac644690a2a0635d921199f
```

Esse estado recompõe MyBatis 3.4.5 e a allowlist anterior do gate Java 17. A
tag pública anterior continua sendo `migration/02-java8-wildfly26`; nenhuma
tag nova é criada para o gate interno.
