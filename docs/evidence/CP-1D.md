# Evidência CP-1D — Fundação portátil H2 e qualificação Oracle

## Escopo

- branch de entrega: `checkpoint/cp-1d-portable-persistence`;
- pull request: `#10`;
- commit squash esperado:
  `checkpoint(CP-1D): establish portable persistence foundation`;
- revisão que executou a qualificação Oracle:
  `4758f38ca2c4f3cb9e102b02afb3b426e48a37cb`;
- contrato comum dos dois perfis:
  `java:/jdbc/MigrationDS`, pool `MigrationDS`;
- nenhuma credencial, URL interna, endereço interno ou binário externo integra
  esta evidência.

O CP-1D aprova a fundação de runtime, schema portátil e conexão dos dois
datasources. Fluxos HTTP, mappers MyBatis e qualificação funcional do schema
entram nos checkpoints seguintes.

## Runtimes observados

| Trilha | Java | Banco/driver | Servidor |
| --- | --- | --- | --- |
| `portable-ci` | Zulu 7.56.0.11 CA / OpenJDK 7u352 | H2 1.4.200 em memória | WildFly 9.0.2.Final |
| `oracle-qualified` | Oracle JDK 7u80 | Oracle Database 19c / `ojdbc7` 12.1.0.2.0 | WildFly 9.0.2.Final |

Digests relevantes:

| Artefato | SHA-256 |
| --- | --- |
| Oracle JDK 7u80 | `bad9a731639655118740bee119139c1ed019737ec802a630dd7ad7aab4309623` |
| Zulu OpenJDK 7u352 | `8a7387c1ed151474301b6553c6046f865dc6c1e1890bcf106acc2780c55727c8` |
| Maven 3.8.9 | `3e4c68cdd70f96635e713f36c8fc3ea3182035245d3da2156576710ca0fe4b0c` |
| WildFly 9.0.2.Final | `74689569d6e04402abb7d94921c558940725d8065dce21a2d7194fa354249bb6` |
| H2 1.4.200 | `3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6` |
| `ojdbc7` 12.1.0.2.0 externo | `0d34cddb5726232ad4c0e5db731e930c9c75d8f74b9c4aa449799cc43dd3e829` |
| WAR auditado | `5f1760fb315894d54652d0fdba9c0f7d6a2a131730f864da26ad9431e9e5170e` |

O banner informado para o banco é Oracle Database 19c Enterprise Edition
Extreme Performance, Release `19.0.0.0.0`. Esse banner não identifica o Release
Update instalado; a identificação do RU permanece pendente para a suíte Oracle
funcional que começa com a persistência da aplicação.

Atualização posterior ao fechamento do CP-1D: durante o CP-1E,
`V$VERSION.BANNER_FULL` retornou `Version 19.3.0.0.0`. A referência Oracle do
laboratório passa a ser RU 19.3; patches `one-off` continuam desconhecidos sem
o inventário do Oracle Home.

## Resultado `portable-ci`

O job hospedado do PR `#10`, revisão `4758f38`, foi aprovado em 27 de julho de
2026:

- `repository-baseline`: aprovado em 10 segundos;
- `portable-ci`: aprovado em 46 segundos;
- execução:
  `https://github.com/anderson-sillos/wildfly-migration/actions/runs/30303467900`;
- nenhum secret, Oracle JDK, `ojdbc7` ou rota interna foi fornecido ao runner.

O job baixou os quatro artefatos open source fixados, conferiu os checksums,
executou o `doctor` portátil, construiu e auditou o WAR, aplicou schema/seed H2
duas vezes, executou rollback H2 duas vezes e confirmou o pool no WildFly em
loopback. O resultado é somente `portable-ci`; não declara compatibilidade
Oracle.

## Resultado `oracle-qualified`

Em 27 de julho de 2026, numa máquina com acesso autorizado à rede interna:

- `doctor` Oracle: 59 verificações aprovadas, nenhuma falha ou aviso e nove
  itens futuros não exigidos;
- Java, Maven, WildFly, truststore e `ojdbc7` foram aprovados por versão e
  checksum;
- build Maven no perfil `oracle`: aprovado;
- auditoria: 14 bibliotecas no WAR, bytecode Java 7, H2/`ojdbc7`/APIs do
  contêiner ausentes do WAR;
- configuração real permaneceu em `.env` ignorado;
- WildFly foi copiado para diretório temporário, ligado somente em loopback e
  provisionado com o módulo Oracle externo;
- `java:/jdbc/MigrationDS` foi publicado;
- `test-connection-in-pool` confirmou conexão com o Oracle 19c;
- o runtime temporário foi encerrado e removido;
- o smoke do datasource não executou DDL ou DML no banco.

O resultado `oracle-qualified` deste checkpoint cobre exclusivamente driver,
provisionamento, JNDI e conexão gerenciada. Ele não cobre ainda transações
MyBatis, sequences, timestamps, LOBs ou contratos HTTP.

## Validações executadas

```bash
./scripts/doctor.sh CP-1D --profile oracle --env .env
./scripts/build-cp-1d.sh --profile oracle --env .env
./scripts/validate-cp-1b.sh --release
./scripts/validate-cp-1c.sh
./scripts/validate-cp-1d-selection.sh
./scripts/validate-cp-1d-profiles.sh
./scripts/validate-cp-1d-h2.sh
./scripts/validate-cp-1d-datasources.sh
./scripts/smoke-wildfly9-datasource.sh --profile oracle --env .env
openspec validate create-java-web-migration-lab \
  --type change --strict --no-interactive
git diff --check
```

Os scripts Oracle canônicos foram validados estruturalmente e permaneceram
inalterados. A execução destrutiva de `rollback.sql` não faz parte do smoke de
datasource e exige confirmação explícita de que o usuário conectado pertence a
um schema descartável do laboratório.

## Reprodução

1. Use um checkout limpo da revisão do PR.
2. Forneça externamente os runtimes e drivers fixados nos manifestos.
3. Crie `.env` a partir de `.env.example`; nunca inclua usuário ou senha na URL.
4. Execute primeiro o perfil `ci-h2` sem qualquer configuração Oracle.
5. Em máquina autorizada na rede interna, execute o `doctor`, build e smoke do
   perfil `oracle`.
6. Compare o checksum do WAR com o valor registrado nesta evidência.

## Rollback

Antes do merge, feche o PR e remova somente a branch
`checkpoint/cp-1d-portable-persistence`. Depois do merge, abra um novo PR que
reverta o commit squash do CP-1D; não reescreva `main`.

O rollback Git não remove `.env`, JDKs, Maven, WildFly, H2 ou `ojdbc7`
externos. O smoke usa uma cópia temporária do WildFly e a remove
automaticamente. O H2 existe somente em memória e desaparece com o processo.
O smoke Oracle não altera dados, portanto não há rollback de banco associado a
este checkpoint.

Para limpar apenas o WAR e demais derivados Maven, use o wrapper de build ou
`mvn clean` com o toolchain aprovado. Não remova o checkout, o diretório amplo
de ferramentas ou qualquer schema Oracle como parte do rollback Git.

## Limitações abertas

- H2 em modo Oracle não substitui Oracle Database 19c.
- O RU foi identificado posteriormente como 19.3; o inventário opcional de
  patches `one-off` ainda não foi fornecido.
- A conta Oracle usada no smoke comprovou conexão; seus privilégios mínimos
  para DDL/DML serão verificados antes de executar scripts contra um schema
  descartável.
- Fluxos web, MyBatis, transações e estado persistido entram no CP-1E.
