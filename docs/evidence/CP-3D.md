# Evidência CP-3D — Gate Java 17

## Escopo e entrada

O CP-3D fecha o gate Java 17 com OpenJDK Temurin 17.0.20+8, Maven 3.9.16,
WildFly Community 26.1.3.Final e Jakarta EE 8 no namespace `javax`. A entrada
é a fase 2 `migration/02-java8-wildfly26`; a única exceção web deliberada é
Tiles 2.1.4 com o TLD 2.0 histórico, conforme
[`cp-3d-java17-gate.md`](../cp-3d-java17-gate.md).

As qualificações foram executadas no commit
`7ece22c7e9adb8877589eb78a99b566553667a0e` e produziram o mesmo WAR,
`0e431a2ec85e0918cc89ed91dcec5715e7872e18b8d57441d7ae781b4a5a5d5b`.

## Resultado comprovado

| Perfil | Runtime/banco | Contratos | Persistência | Resultado |
| --- | --- | ---: | --- | --- |
| `portable-ci` | Java 17 / WildFly 26 / H2 2.4.240 | 14/14 | MyBatis, transações, upload, logging e descoberta | aprovado |
| `oracle-qualified` | Java 17 / WildFly 26 / Oracle 19.3.0.0.0 | 14/14 | `ojdbc17-23.26.2.0.0`, rollback, TIMESTAMP(6), BLOB e limpeza | aprovado |

Os relatórios versionados são
[`portable-ci.json`](../../migration/evidence/CP-3D/portable-ci.json) e
[`oracle-qualified.json`](../../migration/evidence/CP-3D/oracle-qualified.json).
O script [`validate-cp-3d.sh`](../../scripts/validate-cp-3d.sh) confirma os 14
nomes do baseline, os estados `passed`, o mesmo commit/WAR nos dois perfis,
Tiles/TLD e o manifesto.

## Manifesto e exceções adiadas

[`manifest.properties`](../../migration/evidence/CP-3D/manifest.properties)
registra as dependências modernizadas, as origens já fixadas no runtime da
fase 3, a allowlist de 17 bibliotecas, o checksum da árvore Maven, o checksum
do WAR e as exceções adiadas. Tiles/TLD, a ponte `log4j-over-slf4j`,
Reflections 0.10.2 e Commons FileUpload 1.6.0 permanecem apenas para preservar
o contrato `javax`; suas substituições estão planejadas para o CP-3G.

## Conclusão

O Java 17 é compatível com a aplicação modernizada mantendo o menor impacto
no legado: os contratos funcionais e o estado persistido foram aprovados em
H2 e Oracle, sem divergência entre os perfis. O CI remoto deve continuar
classificado como `portable-ci`; a qualificação Oracle permanece uma etapa
interna com credenciais externas.

## Reprodução e rollback

O passo a passo está em [`cp-3d-reproduction.md`](../cp-3d-reproduction.md).
O rollback documentado retorna ao checkout
`migration/02-java8-wildfly26`, sem mutação de banco, conforme
[`rollback.properties`](../../migration/evidence/CP-3D/rollback.properties).

O checkpoint deve ser integrado sem criar fase ou tag pública. A integração deve usar o assunto
`checkpoint(CP-3D): approve Java 17 gate`; a próxima atividade permanece o
CP-3E, ainda não iniciada.
