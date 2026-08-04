# CP-3H / atividade 3.36 — XML moderno e seguro

## Decisão

O CP-3H mantém as versões já aprovadas no POM moderno:

- MyBatis `3.5.19`;
- XMLBeans `5.3.0`, com tipos regenerados do XSD durante o build;
- dom4j `2.2.0`, usando o `XMLReader` seguro da aplicação.

Não foi introduzida uma biblioteca XML adicional. `xml-apis`, Geronimo StAX,
`stax-api` e `ojdbc7` continuam ausentes do POM e do WAR. A API `log4j-api`
transitiva do XMLBeans permanece somente como API; o backend é fornecido pelo
WildFly e não é empacotado pela aplicação.

## Verificação

O gate executável é:

```bash
./scripts/validate-cp-3h-xml.sh --env .env --execute
```

Ele recompila o perfil `ci-h2,cp-3e-jakarta11` com Java 21/Maven 3.9.16,
confirma a regeneração de `wildflyMigrationPedido1`, extrai o WAR e executa:

- fixture XML válida, validação por XSD, namespace e round-trip XMLBeans;
- documento legítimo com dom4j 2.2.0;
- rejeição de XXE e de expansão de entidades sem leitura externa.

O resultado sanitizado está em
`migration/evidence/CP-3H/xml-ci-h2.json`. A execução usa H2 somente como
classificação portátil do ambiente; os testes XML não dependem de banco.

## Limites e rollback

Esta atividade comprova a geração e o parsing XML no destino Jakarta/Java 21,
mas não qualifica Oracle nem provisiona o driver final no WildFly. Essas
decisões pertencem às atividades 3.37–3.40. O rollback retorna ao commit
integrado do CP-3G e restaura somente o estado anterior das versões e da
geração XML; não altera schema ou dados Oracle.
