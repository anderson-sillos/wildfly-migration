# Evidência CP-3A — Entrada no Java 17

## Escopo

Esta página registra as atividades 3.1 a 3.5: partir do estado público e
imutável `migration/02-java8-wildfly26`, executar e recompilar a aplicação no
Java 17 sobre o mesmo WildFly 26.1.3.Final, promover esse runtime e encerrar o
checkpoint com evidências separadas H2 e Oracle. H2 nunca é reclassificado
como qualificação Oracle.

## Materialização da entrada

A tag foi materializada em um Git worktree destacado no commit
`0440337d2256581666994f3192bf6c3516ce590e`, com status limpo. Dentro desse
worktree, Temurin 8u492-b09 e Maven 3.9.16 reconstruíram o WAR e a árvore Maven
da fase 2.

Os resultados reproduziram exatamente o manifesto aprovado:

- WAR SHA-256
  `62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2`;
- árvore Maven SHA-256
  `8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca`;
- bytecode Java 8, major `52`;
- 20 bibliotecas em `WEB-INF/lib`.

Nenhum arquivo-fonte, POM, descritor, biblioteca ou byte do WAR foi alterado
para a tentativa.

## Tentativa no runtime seguinte

O harness iniciou uma cópia temporária do WildFly 26 em loopback usando
Eclipse Temurin OpenJDK 17.0.20+8 e implantou diretamente o WAR da tag:

```bash
git worktree add --detach /tmp/wildfly-migration-cp3a-phase2 \
  migration/02-java8-wildfly26

/tmp/wildfly-migration-cp3a-phase2/scripts/build-cp-2c.sh \
  --profile ci-h2 \
  --env /caminho/seguro/wildfly-migration.env

MIGRATION_SOURCE_COMMIT=0440337d2256581666994f3192bf6c3516ce590e \
  ./scripts/smoke-wildfly9-datasource.sh \
    --server 26 \
    --java 17 \
    --profile ci-h2 \
    --env /caminho/seguro/wildfly-migration.env \
    --war /tmp/wildfly-migration-cp3a-phase2/app/target/wildfly-migration.war \
    --contract-result app/target/contract-results/cp-3a-before-ci-h2.json
```

Uma tentativa preliminar dentro do sandbox encontrou
`java.net.SocketException: Operation not permitted` ao enumerar interfaces.
Ela foi descartada como limitação do executor, pois ocorreu antes da aplicação.
A execução válida abriu somente as portas de loopback documentadas.

## Conclusão comprovada

O WAR Java 8 da fase 2 iniciou sem correção no Java 17/WildFly 26. O servidor,
o deployment e `java:/jdbc/MigrationDS` ficaram ativos, e os 14 contratos
portáteis passaram: saúde, listagem, criação, detalhe, sessão, upload e limite,
formulário e importação XML, rejeições XML/validator/XXE/expansão e estado
persistido.

A descoberta Reflections preservou o conjunto e a ordem dos validadores; não
foram observados `ClassNotFoundException`, `NoClassDefFoundError`,
`LinkageError`, `InaccessibleObjectException` ou
`UnsupportedClassVersionError`. O aviso conhecido `WFLYLOG0100` do Log4j 1
permaneceu e continua classificado como `INC-008`, adiado ao CP-3B.

Isso comprova compatibilidade de execução portátil do binário anterior, não
compatibilidade de recompilação com o JDK 17, suporte oficial de cada
dependência nem comportamento Oracle. A atividade 3.2 ainda deve executar o
build com Java 17 e verificar se alguma correção mínima é necessária. A
qualificação Oracle permanece pendente para o encerramento do CP-3A.

As evidências legíveis por máquina estão em
`migration/evidence/CP-3A/before-runtime.properties` e
`migration/evidence/CP-3A/contract-before-ci-h2.json`.

## Recompilação no Java 17 — atividade 3.2

A tentativa natural de executar o Maven 3.9.16 no Temurin 17 falhou antes do
compilador, porque o Enforcer ainda aceitava somente `[1.8,1.9)`. Depois de
liberar essa política no wrapper, os 32 arquivos-fonte compilaram sem
alteração. O
Maven empacotou o WAR, mas o auditor do laboratório falhou porque sua lista
fechada aceitava somente bytecode major `51` ou `52`.

As duas incompatibilidades foram catalogadas como `INC-011` e `INC-012`. As
correções ficaram restritas ao harness:

- `scripts/build-cp-3a.sh` seleciona Java 17 e Maven 3.9.16;
- o wrapper compartilhado sobrepõe temporariamente faixa do Enforcer,
  `source=17` e `target=17` pela linha de comando;
- a auditoria passa a reconhecer explicitamente major `61`.

Nenhum fonte da aplicação, POM, descritor, versão ou escopo de dependência foi
alterado. O POM permanece Java 8 por padrão até a promoção coordenada prevista
na atividade 3.4. Essa escolha preserva, durante as atividades 3.1 a 3.3, a
reprodução byte a byte do WAR da fase 2 pelo caminho
`scripts/build-cp-2c.sh`.

O commit de implementação `fa87f1d8f6c74e1be1f7d978ada04ea743b7e551`
produziu:

- WAR Java 17, major `61`, SHA-256
  `afc4d98594c3cf7113018f78fab4e4be6b7c0202bbe5cbd9b5e1db8390cbc294`;
- os mesmos 20 JARs em `WEB-INF/lib`;
- a mesma árvore de 21 dependências, SHA-256
  `8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca`;
- os 14 contratos H2 aprovados no Java 17/WildFly 26.

O log não apresentou erro de classloader, encapsulamento forte ou versão de
classe. Permaneceram somente avisos já conhecidos do baseline, incluindo
`INC-008` para Log4j 1, e o aviso de API obsoleta no código de descoberta que
será tratado junto da atualização do Reflections.

### Conclusão comprovada da atividade 3.2

O projeto não está apenas executando um binário Java 8 em uma JVM mais nova:
os mesmos fontes foram efetivamente recompilados para Java 17, gerando
bytecode major `61`, implantados no WildFly 26 e aprovados pelos mesmos 14
contratos portáteis. Para o escopo exercitado, nenhuma correção de código ou
troca de biblioteca foi necessária; as únicas barreiras eram proteções do
processo de build e verificação.

Essa conclusão ainda não representa o encerramento do CP-3A. Naquele ponto, a
configuração Java 17 ainda não era o padrão do POM/CI, a matriz de
compatibilidade das dependências ainda não havia sido produzida, o H2
precisava ser revisado e a trilha Oracle permanecia pendente.

As evidências adicionais estão em
`migration/evidence/CP-3A/before-build.properties`,
`migration/evidence/CP-3A/after-build.properties` e
`migration/evidence/CP-3A/contract-after-ci-h2.json`.

## Matriz de dependências — atividade 3.3

A [matriz de modernização](../cp-3a-dependency-matrix.md) confronta cada
dependência direta da fase 2 e seu módulo Oracle externo com:

- versão ou mecanismo candidato;
- requisito de Java e compatibilidade com o gate EE 8/`javax`;
- mudanças diretas e transitivas esperadas;
- impacto, decisão, atividade de aplicação e destino final.

A análise decidiu atualizar MyBatis, a linha `javax` do FileUpload,
Reflections, XMLBeans, dom4j e o driver Oracle; remover Log4j 1 e as APIs XML
duplicadas; e manter Tiles 2.1.4 somente como exceção temporária. Também
registrou as duas transições deliberadas: ponte Log4j sobre SLF4J apenas
enquanto existirem imports antigos e Reflections 0.10.2 apenas até a descoberta
por `ServletContainerInitializer`.

### Conclusão comprovada da atividade 3.3

As versões candidatas e o efeito esperado sobre todas as 20 bibliotecas do WAR
da fase 2 estão rastreáveis antes da primeira atualização. A decisão não se
baseia somente em “compilar no Java 17”: separa suporte publicado,
compatibilidade EE, riscos de classloader, logging, XML, empacotamento e
transitivas.

Esta atividade é documental e não altera POM, código, runtime nem WAR. Portanto,
o resultado executável comprovado em 3.2 permanece inalterado e cada hipótese
da matriz ainda precisa ser confirmada na atividade que aplica a respectiva
troca.

## Promoção do runtime — atividade 3.4

Java 17 deixou de ser uma sobrescrita temporária do wrapper e passou a ser o
padrão do POM, dos dois perfis Maven, do `doctor` e do CI portátil. O runtime
fixa Eclipse Temurin 17.0.20+8, WildFly comunitário 26.1.3.Final, Maven 3.9.16
e H2 2.4.240; origem, licença e SHA-256 estão no manifesto
`runtime/phase3/java17-wildfly26/runtime-manifest.tsv`.

O H2 2.4.240 possui módulo e perfil próprios e continua somente em memória,
fora do WAR e sem console ou listener. O cache único preserva também o H2
1.4.200 para não apagar a identidade das fases anteriores. A consulta do
harness foi ajustada de `INFORMATION_SCHEMA.CONSTRAINTS` para
`INFORMATION_SCHEMA.TABLE_CONSTRAINTS`, disponível nas duas versões aprovadas.

A sonda MyBatis encontrou ainda a incompatibilidade natural `INC-013`: no H2
2.4.240, a constraint H2 `STATUS IN (...)` falhou ao ser avaliada por outra
conexão depois da criação do schema. Comparações `OR` foram normalizadas de
volta para `IN`; o adaptador H2 passou então a expressar o mesmo conjunto
fechado por `CASE`. Java, mappers, WAR e schema Oracle não foram alterados.

O perfil Oracle permanece separado, com as mesmas variáveis externas e o
`ojdbc7` ainda provisionado como módulo. A troca do driver não foi antecipada:
ela continua pertencendo à atividade 3.14.

### Conclusão comprovada da atividade 3.4

A configuração padrão do projeto agora representa de fato o gate Java
17/WildFly 26; não depende mais das três propriedades `-D` que viabilizaram a
experiência da atividade 3.2. O H2 ativo possui identidade, origem e isolamento
próprios, enquanto a trilha Oracle permanece independente.

Esta conclusão comprova a promoção estrutural e as validações do runtime H2 da
atividade, não o encerramento do CP-3A. Os contratos completos H2/Oracle, a
auditoria final, os relatórios sanitizados e o rollback executado serão
consolidados na atividade 3.5.

## Fechamento do CP-3A — atividade 3.5

O commit de implementação
`737feb6f4d08aca24a580d5421af4437b1b45b15` foi reconstruído separadamente nos
perfis `ci-h2` e `oracle`. Os dois builds produziram o mesmo WAR:

- SHA-256
  `9206fd3b66ed00cd01bade70f2594102ec3b75d1d817ed317d6fabaca9459704`;
- bytecode Java 17, major `61`;
- 20 JARs em `WEB-INF/lib`;
- árvore Maven SHA-256
  `8ad318314d7f5b97bfd0ec4d00c38dc1512584fe1cdad4c04ae11d3999b0c2ca`;
- nenhum driver H2 ou Oracle dentro do WAR.

| Trilha | Runtime e banco | Contratos | Resultado |
| --- | --- | ---: | --- |
| `portable-ci` | Java 17, WildFly 26.1.3 e H2 2.4.240 em memória | 14/14 | aprovado |
| `oracle-qualified` | Java 17, WildFly 26.1.3, `ojdbc7` externo e Oracle Database 19c RU 19.3 | 14/14 | aprovado |

No Oracle, a comparação de estado confirmou schema, seed, criação por
contrato, BLOB do upload, importação XML e rejeição de estado inválido. A sonda
de persistência aprovou commit e rollback MyBatis, round-trip de
`TIMESTAMP(6)`, BLOB e remoção dos registros transitórios `LAB-SMOKE-*`.

Os relatórios sanitizados e vinculados ao mesmo commit e WAR são:

- `migration/evidence/CP-3A/contract-ci-h2.json`;
- `migration/evidence/CP-3A/contract-oracle.json`;
- `migration/evidence/CP-3A/oracle-state.json`;
- `migration/evidence/CP-3A/oracle-persistence.json`;
- `migration/evidence/CP-3A/closure.properties`.

### Auditoria do cache remoto

A execução GitHub Actions
[`30593334871`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30593334871)
restaurou por prefixo a geração anterior do cache de runtimes, preservou os
cinco arquivos válidos, baixou somente `h2-2.4.240.jar` de sua origem
registrada e validou os seis checksums. Depois da trilha portátil verde, gravou
a geração exata
`runtime-archives-v4-Linux-X64-81be8d5ba4c568449785f9c9a3f8f3e90afb65f642660b1c6453702df688cc1a`.

Portanto, o H2 2.4.240 participa do mesmo cache que os demais arquivos de
runtime. O H2 1.4.200 continua presente para reproduzir as tags históricas, e
os próximos commits do mesmo contexto podem restaurar a nova chave sem baixar
novamente os componentes.

### Rollback comprovado

A execução validou o rollback para `migration/02-java8-wildfly26` sem alterar
o checkout atual.
A tag anotada `migration/02-java8-wildfly26` foi materializada em worktree
temporário no commit
`0440337d2256581666994f3192bf6c3516ce590e`. O build Java 8 reproduziu
exatamente o WAR
`62c9f723245b4aaebbeef41e63c02974a9f2fc65fc6e8758f956d03ab7f466f2`,
bytecode major `52`, 20 bibliotecas e a árvore Maven histórica. O worktree
permaneceu limpo e foi removido depois da verificação; o schema Oracle não foi
alterado. A evidência está em
`migration/evidence/CP-3A/rollback.properties`.

### Conclusão comprovada do checkpoint

O CP-3A comprova que os mesmos fontes da fase 2 podem ser recompilados e
executados com Java 17 no WildFly 26.1.3, preservando os 14 comportamentos
congelados tanto no H2 quanto no Oracle 19c. As correções necessárias até aqui
ficaram no toolchain, na auditoria e no adaptador H2; código funcional,
mappers, schema Oracle e conjunto de dependências permaneceram inalterados.

Isso não declara as bibliotecas legadas mantidas, o WildFly 26 ou o `ojdbc7`
como destino sustentável de produção. O checkpoint apenas estabelece um gate
Java 17 verde e reversível para que as dependências sejam modernizadas
isoladamente a partir do CP-3B.

## Rollback

A tentativa usa somente um worktree destacado, uma cópia temporária do
WildFly e H2 em memória. O rollback das atividades 3.1 e 3.2 consiste em
encerrar o runtime temporário e remover o worktree criado para a tag. Para a
atividade 3.4, reproduza a fase 2 em outro worktree destacado na tag
`migration/02-java8-wildfly26`; o POM ativo já foi promovido a Java 17. A
instalação externa do WildFly e o schema Oracle não são alterados.
