# CP-3I — Manifesto do gate Java 21

## Objetivo

O manifesto de 3.43 amarra o gate Java 21 ao runtime realmente utilizado, ao
WAR testado e às evidências de persistência e contratos. Ele não substitui a
qualificação Oracle: H2 continua classificado somente como `portable-ci` e o
Oracle 19c como `oracle-qualified`.

## Geração

Depois de construir o WAR Jakarta, execute:

```bash
./scripts/generate-cp-3i-manifest.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --output migration/evidence/CP-3I/manifest.properties
./scripts/validate-cp-3i-manifest.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war
```

O gerador lê versões, licenças, origem e checksums do runtime em
`runtime/phase3/java21-wildfly41/runtime-manifest.tsv`, calcula o SHA-256 e a
quantidade de bibliotecas do WAR e registra o commit Git usado. O campo
`workingTree=false` somente é válido para uma execução sem alterações
pendentes além do próprio arquivo de evidência.

## Conteúdo e proveniência

O arquivo registra Temurin 21.0.12+8, WildFly comunitário 41.0.0.Final, H2
2.4.240, Oracle 19.3.0.0.0, `ojdbc17` 23.26.2.0.0, Maven 3.9.16, Jakarta EE
11, as dependências finais, o escopo dos drivers e os caminhos das evidências
CP-3H/CP-3I. A origem, a licença e o checksum de cada arquivo de instalação
permanecem no manifesto de runtime para manter uma única fonte de proveniência.

Nenhum endereço JDBC, usuário, senha, wallet ou outro segredo pode aparecer no
manifesto. O driver Oracle e o H2 ficam fora do WAR; o primeiro é módulo do
WildFly e o segundo é apenas runtime do CI.

## Verificação e rollback

O validador confere marcadores, commit existente, `workingTree`, checksum e
contagem de bibliotecas quando o WAR está disponível, além de todas as
referências de evidência. Em caso de divergência, reconstrua o WAR com o mesmo
perfil antes de gerar o manifesto novamente.

Para retornar ao último gate aprovado, faça checkout do commit integrado do
CP-3H e descarte apenas artefatos derivados em `app/target`; não remova schema
Oracle nem dados permanentes.
