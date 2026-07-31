# Gate Java 17 no WildFly 26

Esta configuração materializa a atividade 3.4 sem criar uma nova fase pública:

| Componente | Versão fixa |
| --- | --- |
| Java | Eclipse Temurin OpenJDK 17.0.20+8 |
| WildFly comunitário | 26.1.3.Final |
| Maven | 3.9.16 |
| H2 de teste | 2.4.240 |
| API web | Jakarta EE 8, ainda em pacotes `javax.*` |

O [manifesto](runtime-manifest.tsv) registra origem, licença e SHA-256. O
WildFly 26 é um runtime de transição EOL e não representa o destino final.

O H2 2.4.240 é infraestrutura exclusiva do perfil `ci-h2`: o JAR permanece
fora do WAR, é provisionado como módulo do WildFly e usa somente uma URL
`jdbc:h2:mem:` sem console ou listener. O H2 1.4.200 continua registrado no
runtime histórico e no cache único para que as tags anteriores permaneçam
reproduzíveis.

O perfil `oracle` continua separado e ainda usa o `ojdbc7` externo nesta
atividade. A atualização do driver pertence à atividade 3.14; nenhuma aprovação
H2 pode ser promovida a `oracle-qualified`.
