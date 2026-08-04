# Seleção do runtime CP-3J — Java 25/WildFly 41

## Decisão da atividade 3.46

Em 04/08/2026, a distribuição selecionada para o próximo gate foi o Eclipse
Temurin OpenJDK 25.0.4+7 para Linux x64. A release GA é a mais recente da
linha Temurin 25 consultada no repositório oficial; o arquivo, URL e checksum
publicado estão fixados em [`runtime-manifest.tsv`](runtime-manifest.tsv).

O servidor continua sendo o WildFly Community 41.0.0.Final, release final
oficial de 16/07/2026. A página de downloads do projeto e o release GitHub
publicam o tgz, SHA-1 e assinatura; o SHA-256 efetivo usado pelo laboratório
também está registrado no manifesto.

O H2 2.4.240 permanece a versão estável mais recente publicada pelo projeto e
no Maven Central. Ele é somente infraestrutura `portable-ci`, em memória, e
não será incluído no WAR. O `ojdbc17` continua externo ao WAR e ao runtime
open source, provisionado somente no perfil Oracle.

## Compatibilidade e limites

O WildFly 41 recomenda Java SE 25 por ser o LTS mais recente e informa que os
variants executam bem em Java 25, 21 e 17. A certificação Jakarta EE 11
publicada pelo projeto cobre SE 17 e SE 21; portanto, o CP-3J fará uma
qualificação específica da aplicação em SE 25 e não tratará a recomendação do
servidor como prova automática de compatibilidade EE.

Esta escolha rejeita Oracle JDK, JBoss EAP, WildFly Preview e builds nightly:
o laboratório precisa de uma distribuição OpenJDK e de um WildFly comunitário
final, ambos reproduzíveis e com origem, licença e checksum fixados.

## Proveniência consultada

- [Eclipse Temurin 25.0.4+7](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4%2B7)
  e [arquivo/checksum Linux x64](https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4%2B7/OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz.sha256.txt);
- [Downloads WildFly 41](https://www.wildfly.org/downloads/) e
  [release comunitária 41.0.0.Final](https://github.com/wildfly/wildfly/releases/tag/41.0.0.Final);
- [H2 2.4.240 no projeto](https://github.com/h2database/h2database/releases/tag/version-2.4.240)
  e [Maven Central](https://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/).

As URLs acima são referências de origem, não instruções para versionar
binários. O cache portátil usa uma única chave e o índice
`runtime/portable-runtime-sources.tsv`; segredos e drivers Oracle permanecem
fora do cache portátil.
