# Evidência CP-1G — Baseline legado completo

## Escopo

- branch: `checkpoint/cp-1g-complete-legacy-baseline`;
- estado verde anterior: squash `8ca6b1b`, fechamento do `CP-1F`;
- runtime oficial: Oracle JDK 7u80, Maven 3.8.9, WildFly 9.0.2.Final,
  `ojdbc7` 12.1.0.2.0 e Oracle Database 19c RU 19.3;
- runtime portátil: Zulu OpenJDK 7u352, Maven 3.8.9, WildFly 9.0.2.Final e
  H2 1.4.200 em memória;
- bind HTTP e management restrito a loopback;
- nenhum binário, segredo, URL JDBC, identidade do schema ou log bruto é
  versionado nesta evidência.

## Baseline congelado

`migration/baselines/01-legacy/` registra:

- 14 resultados normalizados do contrato HTTP externo;
- estado Oracle de referência, objetos `LAB_*`, seed `LAB-0001` e efeitos
  persistidos esperados;
- matriz H2/Oracle separada, sem promover H2 a qualificação oficial;
- sete componentes de runtime, build, banco e drivers com versão, origem,
  licença e checksum quando aplicável;
- 24 dependências Maven diretas e transitivas, das quais quatro são
  `provided` e 20 integram `WEB-INF/lib`;
- WAR SHA-256
  `9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`;
- árvore Maven SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`.

O catálogo `migration/incompatibilities.tsv` e seu template estabelecem desde
este checkpoint o vínculo entre tentativa natural, assinatura sanitizada,
causa, correção mínima, evidência antes/depois, regressão e rollback.

## Validação estática e de empacotamento

Executada na branch do checkpoint:

```bash
./scripts/validate-cp-1g-baseline.sh
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war
./scripts/validate-documentation.sh
```

Resultado: 14 cenários, 24 dependências, 20 JARs e os dois checksums congelados
foram reconciliados sem divergência.

## Resultados de runtime

As execuções finais `portable-ci` e `oracle-qualified`, o commit revisado e o
run do GitHub Actions serão registrados nesta seção antes do fechamento do PR.

## Reprodução e rollback

O procedimento completo está em
`docs/legacy-baseline-reproduction.md`: preparação externa, checkout limpo,
H2, Oracle, verificação, limpeza e rollback.

Até a criação da tag, o retorno deve ser feito por novo PR que reverta o futuro
squash do `CP-1G` e restaure `8ca6b1b`. Depois da publicação,
`migration/01-legacy-baseline` é imutável. Nenhum rollback Git executa
`rollback.sql`, remove o schema Oracle ou apaga a conta.

## Limitações conhecidas

- H2 continua sendo somente `portable-ci`;
- Oracle exige rede interna e componentes proprietários externos;
- o inventário de patches Oracle `one-off` não foi fornecido;
- todo o runtime e as bibliotecas da fase 1 são históricos e vários estão EOL
  ou possuem vulnerabilidades conhecidas, portanto permanecem isolados.
