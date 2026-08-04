# CP-3I/3.42 — Contratos completos e comparação com o baseline

## Objetivo

Reexecutar no Java 21/WildFly 41 os 15 cenários HTTP da aplicação Jakarta e
compará-los com os 14 cenários congelados no baseline legado. Os 14 cenários
originais devem permanecer \`passed\`; \`protectedFragments\` é a verificação
adicional introduzida no gate Jakarta para confirmar a proteção de \`WEB-INF\`.

## Execução

\`\`\`bash
./scripts/qualify-cp-3i-contracts.sh \\
  --profile ci-h2 --env .env \\
  --war app/target/cp3f-jakarta11/wildfly-migration.war \\
  --result migration/evidence/CP-3I/contract-ci-h2.json

./scripts/qualify-cp-3i-contracts.sh \\
  --profile oracle --env .env \\
  --war app/target/cp3f-jakarta11/wildfly-migration.war \\
  --result migration/evidence/CP-3I/contract-oracle.json

./scripts/validate-cp-3i-contracts.sh \\
  --war app/target/cp3f-jakarta11/wildfly-migration.war
\`\`\`

O smoke inicia o WildFly 41 em loopback, configura o datasource correspondente,
implanta o mesmo WAR e executa a suíte HTTP externa. O perfil Oracle deve ser
executado somente na rede interna autorizada; nenhum resultado contém URL ou
credencial.

## Comparação

Cada resultado registra commit, checksum do WAR, runtime, perfil e os cenários
individualmente. A comparação exige igualdade dos 14 nomes e estados do
baseline (\`health\`, listagem, criação, detalhe, sessão, upload, limite,
importação XML válida e inválida, validação de negócio, XXE, expansão de
entidades e persistência) e aprova também \`protectedFragments\`.

O H2 comprova a trilha \`portable-ci\`; o relatório Oracle comprova a mesma
suíte com o driver e o banco oficiais. Nenhum deles é tratado como teste de
carga ou como substituto de uma comparação funcional de produção.

## Rollback

O rollback técnico retorna ao CP-3H por checkout do commit integrado anterior.
Os smokes removem somente os dados transitórios gerados pela própria suíte e
não executam DDL ou restauração destrutiva do schema.
