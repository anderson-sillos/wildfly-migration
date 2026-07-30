# Reprodução da fase 2 a partir de checkout limpo

## Escopo

Este procedimento reproduz Java 8, Maven 3.9.16, WildFly 26.1.3.Final, o WAR,
os 14 contratos e o manifesto da fase 2 sem depender de arquivos derivados de
uma execução anterior. Runtimes, driver JDBC e configuração permanecem fora
do checkout.

Durante a revisão do CP-2D, use o commit exato do PR. Depois do encerramento da
fase, use somente a tag imutável `migration/02-java8-wildfly26`.

A execução de referência da atividade 2.19 partiu do commit
`b3d6d38ce87ebadc04a20d674a900afee44463c8` em um segundo clone temporário,
sem arquivos derivados. Seu
[relatório sanitizado](../migration/evidence/CP-2D/reproduction-oracle.json)
registra a aprovação H2 e Oracle sem dados de conexão.

## 1. Criar o checkout

```bash
git clone https://github.com/anderson-sillos/wildfly-migration.git
cd wildfly-migration
git switch --detach <commit-exato-do-PR>
git status --short
```

Depois da publicação:

```bash
git switch --detach migration/02-java8-wildfly26
```

O status deve estar vazio. Não copie `app/target/`, `.m2`, runtime extraído,
relatórios nem `.env` de outro checkout.

## 2. Preparar componentes externos

Siga [Preparação do ambiente](environment-setup.md) e confira o
[manifesto da fase 2](../migration/baselines/02-java8-wildfly26/). Forneça em
diretório externo:

- Temurin OpenJDK 8u492-b09;
- Apache Maven 3.9.16;
- WildFly comunitário 26.1.3.Final;
- H2 1.4.200 para `ci-h2`;
- `ojdbc7` 12.1.0.2.0 e acesso ao Oracle 19c RU 19.3 somente para `oracle`.

Valide cada arquivo pelo SHA-256 do manifesto antes de extraí-lo. Java,
Maven, WildFly, H2 e `ojdbc7` não são copiados para o Git nem para o WAR.

## 3. Criar configuração externa

Crie um arquivo fora do checkout, com permissão restrita ao usuário:

```bash
install -m 0600 .env.example \
  /caminho/seguro/wildfly-migration-cp2d.env
```

Preencha somente os caminhos exigidos e mantenha:

```dotenv
MIGRATION_CHECKPOINT=CP-2D
LAB_BIND_ADDRESS=127.0.0.1
```

O perfil é escolhido por `--profile`, não por variável no `.env`. No perfil
H2, não informe credenciais Oracle. No perfil Oracle, URL, usuário, senha,
wallet e caminho do driver ficam apenas no arquivo externo ou no mecanismo de
segredos autorizado.

Não publique esse arquivo, seu conteúdo, o `server.log` Oracle ou um relatório
que contenha endereço interno.

## 4. Reprodução portátil

```bash
./scripts/reproduce-cp-2d.sh \
  --profile ci-h2 \
  --env /caminho/seguro/wildfly-migration-cp2d.env
```

O executor:

1. recusa alterações rastreáveis no checkout;
2. executa a mesma validação-base local e remota;
3. diagnostica Java, Maven, WildFly e H2 sem exigir identidade Git,
   autenticação GitHub ou Docker, pois esses itens não participam da execução;
4. cria o WAR e a árvore Maven a partir do fonte;
5. provisiona uma cópia temporária do WildFly em loopback;
6. executa os 14 contratos;
7. compara o resultado com a fase 1;
8. compara WAR, árvore Maven e cada JAR com o manifesto da fase 2;
9. confirma que nenhum arquivo rastreável foi alterado.

O relatório derivado fica em:

```text
app/target/contract-results/cp-2d-reproduction-ci-h2.json
```

Ele deve registrar `portable-ci`, `cleanCheckoutBefore` e
`cleanCheckoutAfter` como `passed`, mas Oracle como `not-executed`.

## 5. Reprodução qualificada no Oracle

Somente em máquina autorizada na rede interna:

```bash
./scripts/reproduce-cp-2d.sh \
  --profile oracle \
  --env /caminho/seguro/wildfly-migration-cp2d.env
```

O modo Oracle executa primeiro a trilha H2 no mesmo checkout. Depois verifica
o schema descartável, executa os 14 contratos no WildFly 26, compara o estado
Oracle oficial, comprova commit, rollback, `TIMESTAMP(6)` e BLOB, e remove
somente os registros transitórios `LAB-SMOKE-*`.

O relatório final deve registrar os perfis `ci-h2` e `oracle`,
`qualification=oracle-qualified` e `oracleQualified=passed`. O Oracle não é
exposto ao runner hospedado e nenhum segredo é copiado para o relatório.

## 6. Valores esperados

O arquivo
[`manifest.properties`](../migration/baselines/02-java8-wildfly26/manifest.properties)
fixa:

```text
WAR SHA-256: 62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2
árvore Maven SHA-256: 8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca
dependências Maven: 21
JARs em WEB-INF/lib: 20
cenários de contrato: 14
```

Uma divergência deve ser investigada. Não atualize o manifesto apenas para
fazer a reprodução passar.

## 7. Verificação e limpeza

Confira:

```bash
git status --short
sha256sum app/target/wildfly-migration.war \
  app/target/dependency-tree.txt
```

O Git deve continuar limpo; `app/target/` é ignorado e pode ser recriado. O
WildFly usado pelo smoke é temporário e encerra ao final. H2 existe somente em
memória. No Oracle, a automação remove seus registros `LAB-SMOKE-*`, mas não
remove seed, objetos, schema ou usuário.

Arquivos externos e caches compartilhados permanecem fora do checkout. Sua
remoção é uma operação administrativa separada e não faz parte da reprodução.

## 8. Falhas e rollback da reprodução

- Se o checkout não estiver limpo, crie outro clone; não descarte alterações
  desconhecidas automaticamente.
- Se um checksum divergir, interrompa e confira origem, arquivo e versão.
- Se o H2 falhar, não execute Oracle até corrigir a trilha portátil.
- Se o Oracle falhar, preserve somente evidência sanitizada, execute a limpeza
  protegida dos registros transitórios e mantenha o checkpoint sem
  `oracle-qualified`.
- Se o runtime temporário permanecer ativo, use o PID e os caminhos mostrados
  pelo script de smoke; não encerre processos por nome genérico.

O rollback da reprodução consiste em abandonar o checkout isolado e retornar
ao último checkpoint verde. Ele não executa rollback de schema e não altera a
tag da fase 1.
