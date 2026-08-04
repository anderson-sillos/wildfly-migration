# Evidência CP-3J — seleção do runtime OpenJDK 25

A atividade 3.46 fixou a combinação open source que será qualificada nas
próximas tarefas do CP-3J:

| Componente | Seleção | Escopo |
| --- | --- | --- |
| JVM | Eclipse Temurin OpenJDK 25.0.4+7 | runtime do WildFly e compilação do gate |
| Servidor | WildFly Community 41.0.0.Final | servidor comunitário final |
| Banco portátil | H2 2.4.240 | somente `portable-ci`, fora do WAR |
| Banco oficial | Oracle 19c com `ojdbc17` externo | somente `oracle-qualified` |

As versões, licenças, URLs e checksums estão em
[`runtime-manifest.tsv`](../../runtime/phase3/java25-wildfly41/runtime-manifest.tsv)
e a decisão sanitizada está em
[`runtime-selection.properties`](../../migration/evidence/CP-3J/runtime-selection.properties).
O cache portátil mantém todos os arquivos de runtime na chave única derivada
de `runtime/portable-runtime-cache.sha256`; a nova entrada do JDK 25 invalida
essa chave uma vez e passa a ser reutilizada nas execuções seguintes.

O WildFly 41 recomenda Java SE 25 como LTS mais recente e informa execução em
Java 25, 21 e 17. A certificação Jakarta EE 11 publicada cobre Java SE 17 e
21; por isso esta seleção é uma decisão de runtime, não uma prova automática
de compatibilidade da aplicação. A prova será produzida nas atividades 3.47 a
3.50.

Oracle JDK, JBoss EAP, WildFly Preview e builds nightly foram rejeitados por
não atenderem ao destino comunitário/open source reproduzível do laboratório.

## Fontes oficiais

- [Eclipse Temurin 25.0.4+7](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4%2B7);
- [WildFly 41.0.0.Final](https://www.wildfly.org/news/2026/07/16/WildFly-41-is-released/);
- [downloads do WildFly](https://www.wildfly.org/downloads/);
- [H2 2.4.240](https://github.com/h2database/h2database/releases/tag/version-2.4.240);
- [H2 2.4.240 no Maven Central](https://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/).
