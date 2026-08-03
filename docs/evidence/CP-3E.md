# Evidência CP-3E — Entrada no WildFly 41

## Escopo

O CP-3E iniciou o gate Java 21/WildFly 41 usando o mesmo WAR aprovado no
CP-3D, sem alteração de código ou descritores. O runtime foi fixado em
Eclipse Temurin OpenJDK 21.0.12+8 e WildFly Community 41.0.0.Final; a origem,
licença e os checksums estão no manifesto do gate.

## Resultado comprovado

| Verificação | Resultado |
| --- | --- |
| JVM Java 21 iniciou | aprovado |
| WildFly 41 iniciou em loopback | aprovado |
| WAR do CP-3D tentou deploy sem transformação | aprovado |
| Deploy do WAR EE 8 | rejeitado, como diagnóstico esperado |
| Primeira causa | `ClassNotFoundException: javax.servlet.http.HttpServlet` |
| TLD/Tiles | `javax.servlet.jsp.tagext.TryCatchFinally` ausente |

O resultado legível por máquina é
[`unchanged-war.json`](../../migration/evidence/CP-3E/unchanged-war.json) e o
log sanitizado é
[`unchanged-war-server.txt`](../../migration/evidence/CP-3E/unchanged-war-server.txt).
O catálogo detalhado está em
[`compatibility-observations.tsv`](../../migration/evidence/CP-3E/compatibility-observations.tsv)
e a incompatibilidade natural em
[`CP-3E-wildfly41-entry.md`](../../migration/steps/CP-3E-wildfly41-entry.md).

## Interpretação

O bytecode Java 17 foi aceito pela JVM 21; portanto, a barreira de entrada é o
linkage entre os pacotes `javax.servlet*` do WAR e os módulos Jakarta EE do
WildFly 41. O diagnóstico não qualifica datasource, Oracle ou logging, pois o
deploy falha antes de executar o fluxo web. Esses cenários permanecem
explicitamente pendentes para os gates seguintes.

## Reprodução e rollback

```bash
./scripts/build-cp-3b.sh --profile ci-h2 --env .env --ide-rebuild
./scripts/diagnose-cp-3e-unchanged.sh \
  --env .env \
  --war app/target/wildfly-migration.war \
  --result migration/evidence/CP-3E/unchanged-war.json \
  --diagnostic-log migration/evidence/CP-3E/unchanged-war-server.txt
```

O rollback do diagnóstico retorna ao estado verde do CP-3D e não altera banco
ou histórico. Depois da troca da API `provided`, o teste de entrada deixa de
ser um critério verde; a validação passa a ser a compilação Jakarta e os
contratos do CP-3F.
