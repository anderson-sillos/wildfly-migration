# Manifesto da fase 2 — Java 8 e WildFly 26

Este diretório congela a composição técnica aprovada na modernização de baixo
impacto. A tag `migration/02-java8-wildfly26` permanece apenas reservada até o
encerramento do CP-2D; a criação da tag faz parte da atividade 2.20.

O WAR foi produzido pela revisão
`9d21c4be5ea2736162691850d872150f1a4c816f` e continuou byte a byte idêntico
nas execuções H2 e Oracle da atividade 2.16. Alterações posteriores apenas em
documentação, validadores ou evidências não mudam a identidade do artefato.

## Conteúdo

- `manifest.properties`: identidade da fase, versões-alvo, checksums do WAR e
  da árvore Maven, contagens e estados de qualificação;
- `components.tsv`: Java, Maven, WildFly, H2, driver Oracle e banco externo,
  com origem, licença, checksum, ciclo de vida e proveniência;
- `maven-dependencies.tsv`: a API Jakarta EE 8 em `provided` e as 20
  bibliotecas efetivamente empacotadas, incluindo dependências transitivas e
  SHA-256 individual;
- `known-limitations.tsv`: exceções deliberadamente mantidas na ponte e o
  checkpoint em que cada uma será tratada.

As respostas funcionais e o estado persistido não são duplicados aqui. Eles
permanecem nas evidências do
[CP-2D](../../evidence/CP-2D/phase2-comparison.json), comparadas com o
[baseline da fase 1](../01-legacy/).

## Validação

Sem argumentos, o comando valida a coerência interna e a proveniência do
manifesto:

```bash
./scripts/validate-cp-2d-manifest.sh
```

Depois de um build CP-2C/CP-2D, a mesma validação compara o WAR, a árvore
Maven, os nomes e os checksums individuais de `WEB-INF/lib`:

```bash
./scripts/validate-cp-2d-manifest.sh \
  --war app/target/wildfly-migration.war
```

O resultado `portable-ci` continua limitado ao H2 em memória. Somente a
evidência `oracle-qualified` comprova o comportamento específico do Oracle
Database 19c RU 19.3.
