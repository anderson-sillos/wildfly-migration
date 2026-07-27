# CP-1D — Seleção do runtime portátil Java 7/H2

## Decisão

O perfil `ci-h2` do baseline fixa:

| Componente | Versão aprovada | Finalidade |
| --- | --- | --- |
| Java | Azul Zulu 7.56.0.11-ca / OpenJDK 1.7.0_352-b01, Linux x64 | executar a trilha `portable-ci` sem distribuir Oracle JDK |
| H2 | `1.4.200` | banco em memória, `MODE=Oracle`, provisionado no WildFly e fora do WAR |

Versão, origem, licença e SHA-256 são definidos em
[`portable-runtime-manifest.tsv`](../runtime/legacy/portable-runtime-manifest.tsv).
As referências são imutáveis: não use `latest`, uma faixa Maven ou outro
artefato que apenas tenha nome semelhante.

Os dois componentes são infraestrutura de teste **EOL**. Eles são permitidos
somente em runner efêmero, com H2 em memória, sem console, listener TCP ou
acesso externo. O resultado recebe a classificação `portable-ci`, nunca
`oracle-qualified`.

## Por que essa combinação

A API oficial da Azul identificou o pacote selecionado como Community
Availability (`CA`), GA, TCK e como a versão mais recente que corresponde ao
filtro Java 7/JDK/Linux x64/`tar.gz`. O pacote é uma build open source do
OpenJDK sob GPLv2 com Classpath Exception e é gratuito para download e uso. O
laboratório fixa a build retornada, em vez de depender do indicador mutável
`latest`: `zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz`.

Foram comparadas duas opções H2:

| Candidato | Observação | Decisão |
| --- | --- | --- |
| `1.3.173` | fornecido pelo WildFly 9; construído com JDK 6; SHA-256 `43908ee9db698cb335e2b85375d68a9d03d818869a0542b85d8d4e416619795b` | rejeitado por ser uma linha ainda mais antiga e oferecer menor margem para o DDL equivalente |
| `1.4.200` | construído com JDK 7u80; executou em Oracle JDK 7u80 e Zulu 7u352; licença dual MPL 2.0/EPL 1.0 | aprovado como módulo explícito de teste |

O uso de H2 1.4.200 exige substituir somente o módulo H2 do runtime de teste.
Ele não adiciona uma dependência à aplicação e não altera o runtime Oracle. A
configuração desse módulo e dos datasources pertence à tarefa `1.19`.

## Evidência da seleção

Em 24 de julho de 2026 foram verificados:

- SHA-256 do Zulu:
  `8a7387c1ed151474301b6553c6046f865dc6c1e1890bcf106acc2780c55727c8`,
  igual ao metadado publicado pela Azul;
- `java -version`: OpenJDK `1.7.0_352`, Zulu `7.56.0.11-CA`;
- Maven 3.8.9 executando sobre esse Zulu;
- SHA-256 do H2:
  `3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6`;
- H2 `1.4.200` iniciando com as duas distribuições Java 7 e aceitando
  `jdbc:h2:mem:<nome>;MODE=Oracle;DB_CLOSE_DELAY=-1`;
- consultas `H2VERSION()` e `SYSTIMESTAMP FROM DUAL`.

Esse smoke comprova compatibilidade de execução, não equivalência com Oracle.
Sequences, constraints, timestamps, LOBs e transações serão tratados por
scripts próprios e qualificados separadamente no Oracle 19c.

## Reprodução exata versus CI portátil

| Trilha | Java | Banco | Classificação |
| --- | --- | --- | --- |
| reprodução histórica | Oracle JDK `1.7.0_80` | Oracle Database 19c com `ojdbc7` | `oracle-qualified`, somente após execução interna |
| validação portátil | Zulu OpenJDK `1.7.0_352` | H2 `1.4.200` em memória | `portable-ci` |

O Zulu não substitui o Oracle JDK 7u80 na evidência histórica. A diferença do
patch level da JVM é deliberada e deve permanecer visível nos relatórios.
Analogamente, aprovação no H2 não comprova SQL, driver, códigos de erro,
timezone, LOB ou comportamento transacional específico do Oracle.

## Reconciliação das entregas anteriores

Os checkpoints integrados permanecem historicamente válidos. O CP-1D entrega
os deltas sem reescrever seus checkmarks:

| Tarefa histórica | Delta causado pelo H2 | Entrega |
| --- | --- | --- |
| `1.3` documentação de ambiente | incluir Java 7 redistribuível, H2, licença, EOL e as duas classificações | `1.16` |
| `1.4` configuração e `doctor` | selecionar `ci-h2` ou `oracle` e exigir somente seu conjunto de pré-requisitos | `1.17` |
| `1.9` scripts Oracle | manter Oracle canônico e criar DDL/massa/limpeza H2 separados | `1.18` |
| `1.14` auditoria do WAR | rejeitar H2 e `ojdbc` no artefato, independentemente do perfil | `1.17` |

## Configuração por perfil

Copie `.env.example` para `.env`, preencha somente o perfil desejado e execute:

```bash
./scripts/doctor.sh CP-1D --profile ci-h2 --env .env --ci
./scripts/doctor.sh CP-1D --profile oracle --env .env
```

O perfil `ci-h2` exige e valida `JAVA7_PORTABLE_*` e `H2_*`, mas não valida
`ORACLE_DB_*`, `OJDBC7_*`, Oracle JDK ou seu truststore. O perfil `oracle`
exige e valida o conjunto histórico e os dados Oracle, mas não exige Zulu ou
H2. Os dois reutilizam Maven 3.8.9 e WildFly 9.0.2 fixados.

No POM, `-Pci-h2` permite qualquer runtime da faixa Java 7 e continua
rejeitando Java 8+. Essa faixa não é uma referência flutuante do laboratório:
o `doctor` exige exatamente Zulu 7.56.0.11 CA/OpenJDK 7u352. O perfil
`-Poracle` e a build sem perfil preservam o range exato do Oracle JDK 7u80.

`.env`, variantes `.env.*`, `.secrets/`, wallets, drivers e arquivos de runtime
são ignorados. O `doctor` rejeita esses caminhos quando encontrados dentro do
checkout ou rastreados pelo Git. A auditoria do WAR rejeita H2, `ojdbc`,
arquivos `.env`, chaves, truststores, wallets e configuração Oracle sensível.

## Fontes primárias

- API de metadados Azul:
  <https://api.azul.com/metadata/v1/zulu/packages/f436b3cb-0115-4814-b7fa-e180747bd68f>
- termos do Azul Zulu:
  <https://www.azul.com/products/core/openjdk-terms-of-use/>
- release oficial H2 1.4.200:
  <https://github.com/h2database/h2database/releases/tag/version-1.4.200>
- artefato H2 no Maven Central:
  <https://repo.maven.apache.org/maven2/com/h2database/h2/1.4.200/h2-1.4.200.jar>
- licença H2:
  <https://h2database.com/html/license.html>
