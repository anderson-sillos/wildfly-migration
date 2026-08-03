# CP-3C — Troca controlada do ojdbc7 pelo ojdbc17

## Incompatibilidade capturada

O `ojdbc7` foi mantido nos gates Java 7/8 e no CP-3A apenas para reproduzir o
runtime histórico. Ele não é o driver apropriado para o gate Java 17. A troca
foi isolada no runtime WildFly, sem mover o JAR para o WAR e sem alterar o
contrato JNDI da aplicação.

## Correção aplicada

- `ojdbc17` 23.26.2.0.0 foi fixado por SHA-256 e fonte no manifesto;
- o novo módulo é `com.oracle.ojdbc17` e o perfil Oracle Java 17 aponta para
  `oracle.jdbc.OracleDriver` nesse módulo;
- `doctor.sh` seleciona `OJDBC17_JAR`/`OJDBC17_SHA256` a partir do CP-3C e
  continua selecionando `OJDBC7_*` nos checkpoints históricos;
- o JAR permanece fora do cache portátil do CI e é fornecido externamente no
  perfil Oracle, enquanto o workflow hospedado permanece exclusivamente H2;
- o smoke e a sonda de persistência escolhem o driver conforme a JVM e mantêm
  o relatório sanitizado separado por perfil.

## Critério de aceite

`validate-cp-3c-ojdbc17.sh` deve passar, o WAR não pode conter `ojdbc*.jar`,
o perfil H2 deve continuar iniciando e a qualificação Oracle deve comprovar
transações confirmadas, rollback, `TIMESTAMP(6)` e BLOB no schema descartável
19c.
