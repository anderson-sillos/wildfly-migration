# Testes de contrato

`run.sh` exercita uma aplicação já iniciada somente por HTTP e pelo estado
observável em novas requisições. A suíte não importa classes, mappers ou
recursos internos do WAR.

Ela cobre:

- saúde e correlação;
- listagem, criação e nova consulta do pedido persistido;
- preferência em sessão;
- upload, metadados persistidos e limite HTTP `413`;
- página multipart e importação XML válida;
- XML válido no XSD rejeitado pelo validador de status inicial;
- XSD inválido, XXE e expansão de entidades sem persistência parcial.

O mesmo arquivo é chamado pelos perfis `ci-h2` e `oracle`. O resultado JSON
registra perfil, qualificação, commit realmente executado, commit de origem,
SHA-256 do WAR, runtime e cenários, mas omite URL base, host, usuário e
credenciais. `--source-commit` é opcional e assume o valor de `--commit`; o CI
o informa explicitamente porque pull requests executam um commit de merge
sintético.

Os resultados esperados independentes do perfil estão congelados em
[`migration/baselines/01-legacy/contract-scenarios.tsv`](../migration/baselines/01-legacy/contract-scenarios.tsv).
Depois da execução, `scripts/validate-cp-1g-baseline.sh` compara o relatório,
o WAR e a árvore Maven com esse baseline.

Exemplo com a aplicação já ativa:

```bash
./contract-tests/run.sh \
  --base-url http://127.0.0.1:18080/wildfly-migration \
  --profile ci-h2 \
  --war app/target/wildfly-migration.war \
  --result app/target/contract-results/ci-h2.json \
  --commit "$(git rev-parse HEAD)" \
  --source-commit "$(git rev-parse HEAD)" \
  --runtime java7-wildfly9.0.2 \
  --correlation-id contrato-manual-001
```

Em Oracle, execute preferencialmente pelo
`scripts/smoke-wildfly9-datasource.sh`, que garante a limpeza dos pedidos
`LAB-SMOKE-*`. As fixtures estáticas ficam em [`fixtures/`](fixtures/).
