# Gate Java 21 no WildFly 41

Esta configuração inaugura o CP-3E: o WAR aprovado no CP-3D é tentado sem
transformação no WildFly Community 41.0.0.Final com Eclipse Temurin OpenJDK
21.0.12+8. A tentativa é diagnóstica; a aplicação ainda declara Jakarta EE 8
e usa o namespace `javax`, portanto não deve ser tratada como o estado Jakarta
aprovado antes do CP-3F.

O [manifesto](runtime-manifest.tsv) registra origem, licença, versão e
checksum. O arquivo H2 é o mesmo H2 2.4.240 já aprovado para o `portable-ci` e
permanece somente como infraestrutura de teste, fora do WAR. O WildFly 41 é a
distribuição comunitária open source do servidor e o Temurin é uma distribuição
OpenJDK; nenhum runtime proprietário é necessário.

O logging final usa a API SLF4J 2.0.18 fornecida pelo módulo do WildFly 41.
`log4j-over-slf4j`, Log4j 1, API SLF4J duplicada e backends próprios não entram
no WAR. O MyBatis fixa `logImpl=SLF4J`; os perfis configuram a categoria de
persistência para permitir a verificação das categorias dos mappers no
`server.log`.

A reprodução do primeiro diagnóstico usa:

```bash
./scripts/diagnose-cp-3e-unchanged.sh \
  --env .env \
  --war app/target/wildfly-migration.war \
  --result migration/evidence/CP-3E/unchanged-war.json \
  --diagnostic-log migration/evidence/CP-3E/unchanged-war.log
```

O script copia o servidor para um diretório temporário, liga apenas em
loopback, tenta o deploy no management port isolado e remove o runtime ao
terminar. O log versionado é sanitizado e não contém caminhos temporários ou
credenciais.
