# CP-3E — Entrada no WildFly 41 com Java 21

O CP-3E abre o segundo gate interno da fase 3. Ele separa a mudança de
servidor/JVM da correção do código: o WAR aprovado no CP-3D é primeiro tentado
sem transformação no WildFly Community 41.0.0.Final com Eclipse Temurin
OpenJDK 21.0.12+8.

## Resultado da entrada

O runtime iniciou corretamente, mas o deploy foi rejeitado porque o WildFly 41
não fornece os módulos `javax.servlet*` usados pelo WAR EE 8. A assinatura
principal foi `ClassNotFoundException: javax.servlet.http.HttpServlet`; Tiles e
o TLD histórico também falharam ao resolver
`javax.servlet.jsp.tagext.TryCatchFinally`.

Isso comprova que a transição precisa migrar o namespace para Jakarta EE 11.
Não comprova ainda compatibilidade de datasource, Oracle, logging ou segurança:
esses itens só serão qualificados depois que o linkage web for corrigido.

## Runtimes e reprodução

Origem, licença, versão e checksum estão em
[`runtime-manifest.tsv`](../runtime/phase3/java21-wildfly41/runtime-manifest.tsv).
O provisionamento local usa os arquivos externos indicados em `.env`; eles não
são versionados. A tentativa e o diagnóstico sanitizado estão em
[`CP-3E`](../migration/evidence/CP-3E/unchanged-war.json) e
[`unchanged-war-server.txt`](../migration/evidence/CP-3E/unchanged-war-server.txt).

O rollback é o estado verde do CP-3D. O próximo passo é ativar o perfil
`cp-3e-jakarta11`, que declara
`jakarta.platform:jakarta.jakartaee-web-api:11.0.0` em `provided`, e executar o
CP-3F para migrar imports e descritores. Nenhuma API EE deve ser empacotada no
WAR; os perfis EE 8 permanecem somente para reproduzir os checkpoints já
aprovados.
