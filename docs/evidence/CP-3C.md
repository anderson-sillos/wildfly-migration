# Evidência CP-3C — XML e Oracle JDBC

## Escopo

Este documento consolida as atividades 3.11 a 3.15 no runtime Java 17 /
WildFly 26.1.3.Final, mantendo javax e o contrato java:/jdbc/MigrationDS. O
checkpoint atualiza XMLBeans e dom4j, remove APIs XML duplicadas, troca o
driver Oracle legado e preserva o perfil H2 portátil.

A entrada do checkpoint é o commit público
84fb02f37e4eaf522d98de66697807b03dfa574a, que encerra o CP-3B.

## Evidências por atividade

| Atividade | Comprovação | Evidência |
| --- | --- | --- |
| 3.11 | XMLBeans 5.3.0, tipos regenerados, schema, namespace e serialização | migration/evidence/CP-3C/xmlbeans-ci-h2.json |
| 3.12 | dom4j 2.2.0, documento legítimo, rejeição de XXE e expansão de entidades | migration/evidence/CP-3C/dom4j-ci-h2.json |
| 3.13 | ausência de xml-apis/Geronimo StAX e uso do módulo java.xml | migration/evidence/CP-3C/java-xml-ci-h2.json |
| 3.14 | H2 portátil e Oracle 19c com ojdbc17, commit, rollback, timestamps e BLOB | migration/evidence/CP-3C/ojdbc17-ci-h2.json e ojdbc17-oracle.json |

As evidências específicas preservam o commit-fonte e o checksum do WAR de
cada atividade. A qualificação final do conjunto usa o WAR
0e431a2ec85e0918cc89ed91dcec5715e7872e18b8d57441d7ae781b4a5a5d5b e o runtime
java17-wildfly26.1.3-ee8.

## Qualificação final

O perfil ci-h2 foi classificado como portable-ci e aprovou datasource, MyBatis,
commit, rollback, round-trip de timestamp, BLOB, XMLBeans e java.xml. O perfil
oracle foi classificado como oracle-qualified contra Oracle Database
19.3.0.0.0, usando ojdbc17-23.26.2.0.0, e aprovou os mesmos contratos de
persistência e a limpeza de dados transitórios.

O CI hospedado continua executando somente H2. O ojdbc17 é fornecido
externamente no host Oracle, não entra no WAR e não faz parte do cache portátil.

## Auditoria de dependências e empacotamento

- WAR Java 17 com 17 bibliotecas na allowlist de
  runtime/phase3/java17-wildfly26/war-libraries.txt;
- mybatis-3.5.19, commons-fileupload-1.6.0, commons-io-2.19.0,
  reflections-0.10.2, xmlbeans-5.3.0 e dom4j-2.2.0 presentes;
- xml-apis, Geronimo StAX, stax-api, ojdbc7 e qualquer driver Oracle ausentes
  de WEB-INF/lib;
- Log4j 1 ausente; log4j-over-slf4j permanece como ponte temporária
  documentada;
- Tiles 2.1.4 permanece como exceção temporária prevista na matriz;
- a árvore Maven e a allowlist são auditadas pelo scripts/validate-cp-3c.sh.

## Rollback

O rollback técnico retorna ao commit CP-3B
84fb02f37e4eaf522d98de66697807b03dfa574a, restaura o módulo Oracle e o
manifesto anteriores e não altera o schema descartável. A qualificação não
executa DDL de rollback fora da limpeza transitória documentada.

## Estado de integração

O PR #21 (checkpoint/cp-3c-xml-jdbc) contém a linha de evolução do checkpoint.
Os artefatos desta atividade estão prontos para revisão e para o commit de
fechamento checkpoint(CP-3C): modernize XML and JDBC; a tarefa 3.15 permanece
pendente até esse commit ser criado e integrado.
