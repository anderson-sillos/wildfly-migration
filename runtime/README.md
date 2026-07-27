# Runtimes

Esta área contém as configurações e automações reproduzíveis para Java, Maven e
WildFly em cada fase e gate do laboratório.

Distribuições, arquivos baixados, Java 7u80, drivers Oracle, credenciais e
segredos não pertencem a este diretório nem ao controle de versão.

O fornecimento isolado do baseline está documentado em
[`legacy/README.md`](legacy/README.md). A reprodução histórica usa
[`legacy/runtime-manifest.tsv`](legacy/runtime-manifest.tsv), enquanto a
trilha H2/Java 7 redistribuível usa
[`legacy/portable-runtime-manifest.tsv`](legacy/portable-runtime-manifest.tsv).
Os dois manifestos permanecem separados para impedir que uma evidência
`portable-ci` seja confundida com `oracle-qualified`.
