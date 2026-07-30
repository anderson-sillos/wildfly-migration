# Evidência CP-2D — Fechamento da modernização de baixo impacto

## Escopo em construção

O checkpoint parte do CP-2C e encerra a fase pública Java 8, WildFly
26.1.3.Final, Jakarta EE 8 com pacotes `javax.*` e Maven 3.9.16. Esta página
será completada pelas atividades 2.19 e 2.20 com reprodução limpa, CI remoto,
rollback e tag pública. O PR #18 foi aberto
como rascunho depois da primeira atividade concluída do checkpoint.

## Comparação integral com a fase 1 — atividade 2.16

A revisão `9d21c4be5ea2736162691850d872150f1a4c816f` produziu o WAR SHA-256
`62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2`.
Os mesmos 14 cenários congelados em `migration/01-legacy-baseline` passaram
nos perfis H2 `portable-ci` e Oracle `oracle-qualified`.

A sonda direta executada antes da limpeza confirmou no Oracle 19c RU 19.3:

- tabelas, sequences e índice canônicos;
- seed `LAB-0001` e seus valores funcionais;
- pedido criado pela suíte HTTP;
- metadados, digest e BLOB do upload recuperados do banco;
- pedido criado pela importação XML;
- ausência de persistência parcial das quatro entradas rejeitadas.

A sonda complementar preservou ainda commit e rollback MyBatis,
`TIMESTAMP(6)`, BLOB byte a byte e limpeza dos dados transitórios. URL, host,
schema, usuário e senha não aparecem nos cinco relatórios sanitizados em
`migration/evidence/CP-2D/`.

## Limite da evidência H2

O resultado H2 continua comprovando somente os fluxos HTTP, o datasource JNDI,
os mappers/transações e a semântica portátil selecionada. Driver Oracle,
sequences, códigos de erro, NLS, timezone, precisão efetiva de timestamps,
locator/streaming de BLOB e semântica transacional específica permanecem
cobertos apenas pela qualificação Oracle. A matriz detalhada continua em
`docs/h2-oracle-differences.md`.

## Correção de metadado do baseline

O estado congelado da fase 1 descreve o upload como tendo 46 bytes. A fixture
da própria tag, seu SHA-256
`8eb0c39e90e87a89c57313d37988ff2a3b67bb43b57ce89956f447a431dc7a3c`
e o BLOB observado no Oracle demonstram 44 bytes em UTF-8. A tag pública e o
arquivo histórico não foram reescritos. A comparação da fase 2 usa os 44 bytes
e o conteúdo byte a byte; a divergência é classificada como correção de
metadado, não como mudança funcional da aplicação.

## Manifesto da fase 2 — atividade 2.17

O [manifesto consolidado](../../migration/baselines/02-java8-wildfly26/)
congela:

- Temurin OpenJDK 8u492-b09, Maven 3.9.16 e WildFly comunitário 26.1.3.Final;
- H2 1.4.200 somente para `portable-ci`, `ojdbc7` externo e Oracle 19c RU
  19.3 para `oracle-qualified`;
- 21 dependências Maven: a API Jakarta EE Web Profile 8 em `provided` e 20
  bibliotecas legadas empacotadas;
- checksum do WAR, da árvore Maven e de cada JAR em `WEB-INF/lib`;
- 12 limitações conhecidas, cada uma com impacto, disposição e evidência.

O manifesto aponta para o mesmo commit-fonte e WAR usados na comparação da
atividade 2.16. A tag `migration/02-java8-wildfly26` permanece reservada e só
será criada no encerramento da atividade 2.20.

## Roteiro para aplicação real — atividade 2.18

O
[roteiro blue/green](../phase2-real-application-migration-runbook.md)
traduz a sequência do laboratório para uma mudança operacional controlada.
Ele não recomenda executar os scripts do laboratório diretamente em produção.

O documento define:

- inventário e baseline obrigatórios antes da janela;
- Green independente e Blue preservado, sem atualização in-place;
- condições para compartilhar o schema Oracle e quiescência de escrita como
  padrão do corte;
- cronograma de T-30 dias até a revisão no próximo dia útil;
- gates de artefato, runtime, datasource, contratos, Oracle, integrações,
  segurança, observabilidade e rollback;
- decisão go/no-go com aceites de aplicação, plataforma, DBA e negócio;
- rollback separado entre tráfego/runtime e recuperação de dados, proibindo
  restauração cega do banco.

Cada comando do laboratório é relacionado a um controle equivalente da
aplicação real, preservando a distinção entre H2 `portable-ci` e a
qualificação Oracle na rede autorizada.
