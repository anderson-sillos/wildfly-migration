# Baseline congelado da fase 1

Este diretório contém os valores normalizados que as fases seguintes devem
preservar. A autoridade imutável será a tag `migration/01-legacy-baseline`;
nenhum commit é gravado nos arquivos para evitar uma referência circular ao
próprio commit que cria a tag.

## Conteúdo

- `baseline.properties`: identidade da fase, checksums reproduzíveis do WAR e
  da árvore Maven e contagens esperadas;
- `contract-scenarios.tsv`: 14 resultados comuns normalizados, independentes
  do perfil e de identificadores gerados;
- `oracle-persisted-state.tsv`: estado canônico Oracle e efeitos persistidos
  que H2 não pode qualificar oficialmente;
- `components.tsv`: runtimes, build, banco e drivers externos, com versão,
  origem, licença e checksum quando existe artefato;
- `maven-dependencies.tsv`: todas as 24 dependências diretas e transitivas,
  inclusive APIs `provided`, além das 20 entradas efetivas de `WEB-INF/lib`.

As diferenças deliberadas do adaptador portátil permanecem na
[matriz H2/Oracle](../../../docs/h2-oracle-differences.md). O comando abaixo
valida os arquivos estáticos e, depois de um build, compara a árvore Maven, o
conteúdo do WAR, seu checksum e um resultado de contratos:

```bash
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war \
  --contract-result app/target/contract-results/ci-h2.json
```

Um resultado `portable-ci` comprova apenas a parte comum. A qualificação do
estado Oracle exige a mesma validação com o relatório `oracle-qualified` e a
execução de `oracle-lab-schema.sh verify` na rede interna.
