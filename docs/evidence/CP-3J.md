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

## Atividade 3.47 — tentativa com a JVM Java 25

O WAR, as dependências e o nível de bytecode permaneceram no mesmo perfil
Jakarta/Java 21. Somente a JVM usada pelo Maven e pelo WildFly foi trocada para
Temurin 25.0.4+7. O build revelou uma incompatibilidade natural: `javac` 25
emite o aviso de localização dos módulos do sistema quando recebe
`-source 21 -target 21`; o `-Werror` já existente transforma esse aviso em erro.

Essa falha é a evidência esperada da 3.47, não uma correção aplicada
antecipadamente. O smoke funcional não foi executado porque não houve WAR
aprovado. O diagnóstico sanitizado e o próximo passo estão em
[`java25-build-expected.properties`](../../migration/evidence/CP-3J/java25-build-expected.properties)
e a correção mínima será tratada exclusivamente na atividade 3.48.

## Atividade 3.48 — correção mínima do JDK 25

A diferença exclusiva do JDK 25 foi corrigida sem alterar código funcional,
dependências, Jakarta EE 11 ou o contrato HTTP. O `maven-compiler-plugin`
passou a usar `--release 21` no perfil Jakarta, em vez de enviar
`-source 21 -target 21` ao `javac`.

Essa mudança mantém bytecode e APIs-alvo em Java 21, mas também informa ao
compilador onde estão os módulos de sistema da plataforma alvo. Com isso, o
warning capturado na 3.47 deixa de existir e o `-Werror` pode continuar ativo
como proteção contra novos avisos reais de compilação.

## Atividade 3.49 — qualificação Java 25 e comparação Java 21

A qualificação executa a mesma suíte HTTP externa nos WARs gerados pelos dois
JDKs: o WAR `cp3f-jakarta11` é compilado com OpenJDK 21 e o WAR
`cp3j-java25` com OpenJDK 25. Cada perfil é executado separadamente no
WildFly 41:

| Perfil | OpenJDK 21 | OpenJDK 25 | Classificação |
| --- | --- | --- | --- |
| H2 2.4.240 em memória | contratos e smoke | contratos e smoke | `portable-ci` |
| Oracle 19c RU 19.3 | contratos e smoke | contratos e smoke | `oracle-qualified` |

O executor [`qualify-cp-3j.sh`](../../scripts/qualify-cp-3j.sh) usa as portas
de loopback 28121/29121 para Java 21 e 28125/29125 para Java 25, de modo que
as duas execuções não compartilham estado de rede. O WildFly recebe sempre
`-b 127.0.0.1 -bmanagement 127.0.0.1`; resultados e logs são rejeitados se
contiverem bind público, URL Oracle, usuário, senha ou parâmetros de conexão.

Antes do smoke, os dois WARs passam pela auditoria de empacotamento do CP-3H.
O agregador registra os checksums dos WARs, os manifestos de
`runtime/phase3/java21-wildfly41` e `runtime/phase3/java25-wildfly41`, a
classificação da execução e os caminhos dos relatórios individuais. O
validador [`validate-cp-3j-qualification.sh`](../../scripts/validate-cp-3j-qualification.sh)
confirma que contratos, empacotamento, portas, segredos e proveniência estão
presentes sem copiar credenciais para o repositório.

No CI hospedado, a trilha H2 é executada para os dois JDKs. A trilha Oracle
continua sendo executada no ambiente autorizado da rede interna, com o mesmo
comando e um `.env` fora do Git:

```bash
./scripts/qualify-cp-3j.sh --profile oracle --env .env \
  --war-java21 app/target/cp3f-jakarta11/wildfly-migration.war \
  --war-java25 app/target/cp3j-java25/wildfly-migration.war
./scripts/validate-cp-3j-qualification.sh --profile oracle
```

Os relatórios gerados são `migration/evidence/CP-3J/<perfil>-qualification.json`,
`<perfil>-java21-contracts.json` e `<perfil>-java25-contracts.json`, sempre
sanitizados. H2 continua sendo evidência portátil; somente os quatro cenários
executados contra Oracle podem receber `oracle-qualified`.

## Fontes oficiais

- [Eclipse Temurin 25.0.4+7](https://github.com/adoptium/temurin25-binaries/releases/tag/jdk-25.0.4%2B7);
- [WildFly 41.0.0.Final](https://www.wildfly.org/news/2026/07/16/WildFly-41-is-released/);
- [downloads do WildFly](https://www.wildfly.org/downloads/);
- [H2 2.4.240](https://github.com/h2database/h2database/releases/tag/version-2.4.240);
- [H2 2.4.240 no Maven Central](https://repo.maven.apache.org/maven2/com/h2database/h2/2.4.240/).
