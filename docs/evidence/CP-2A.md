# Evidência CP-2A — Java 8 no WildFly 9

## Escopo

- entrada: tag `migration/01-legacy-baseline`, commit
  `a7c7b5b92338fc9397967f1916ee525f2dc7c5df`;
- destino: Eclipse Temurin OpenJDK 8u492-b09, Maven 3.8.9 e WildFly
  9.0.2.Final;
- dependências, perfis de banco, JNDI e namespace `javax.*`: inalterados.

## Tentativa antes da correção

O WAR congelado do baseline, SHA-256
`9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`
e bytecode major `51`, iniciou no Java 8/WildFly 9 e aprovou os 14 contratos
H2. A única diferença de inicialização foi o aviso sobre `MaxPermSize`.

A recompilação do worktree destacado com Java 8 terminou com código `1` e a
assinatura esperada:

```text
Detected JDK Version: 1.8.0-492 is not in the allowed range [1.7,1.8).
```

Os registros estruturados são
[`before-runtime.properties`](../../migration/evidence/CP-2A/before-runtime.properties)
e
[`before-build.properties`](../../migration/evidence/CP-2A/before-build.properties).

## Correção e verificações

O código testado foi fixado no commit
`c76f42f4035ac08b13fca478f1d8e375190761b9`. Os dois perfis produziram o mesmo
WAR:

- SHA-256:
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- bytecode Java 8 major `52`;
- 20 JARs em `WEB-INF/lib`;
- árvore Maven com as mesmas 24 dependências e SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`
  do baseline;
- nenhuma API Servlet/JSP/JSTL, H2 ou `ojdbc7` empacotado.

O `doctor` aprovou 107 verificações no perfil H2 e 106 no Oracle, sem falha ou
aviso. O WildFly iniciou sem enviar `MaxPermSize` ao Java 8.

Resultados funcionais sanitizados:

| Trilha | Perfil | Contratos | Resultado |
| --- | --- | ---: | --- |
| `portable-ci` | H2 1.4.200 | 14/14 | aprovado |
| `oracle-qualified` | Oracle 19c RU 19.3 / `ojdbc7` | 14/14 | aprovado |

Os relatórios legíveis por máquina estão em
[`contract-ci-h2.json`](../../migration/evidence/CP-2A/contract-ci-h2.json),
[`contract-oracle.json`](../../migration/evidence/CP-2A/contract-oracle.json)
e
[`after.properties`](../../migration/evidence/CP-2A/after.properties).

O CI hospedado repetirá somente a trilha `portable-ci` sobre o commit do PR. O
resultado Oracle acima foi produzido no host autorizado da rede interna.

## Conclusão comprovada

O CP-2A comprova que a aplicação representativa do laboratório pode migrar
para Java 8 com um conjunto pequeno e isolado de alterações, sem trocar
WildFly, Maven, bibliotecas ou namespace.

### Compatibilidade binária inicial

O mesmo WAR produzido no Java 7, sem recompilação e ainda com bytecode major
`51`, iniciou no Temurin Java 8/WildFly 9 e preservou os 14 cenários
funcionais. Para o código e as bibliotecas efetivamente exercitados, a simples
troca da JVM de execução não introduziu uma quebra funcional imediata.

Essa tentativa foi executada antes de qualquer correção. Portanto, seu
resultado pode ser atribuído à compatibilidade do Java 8 com o binário anterior,
e não a uma adaptação prévia do código.

### Recompilação real para Java 8

A tentativa de recompilar a fonte no Java 8 falhou inicialmente antes do
compilador, porque o Maven Enforcer ainda restringia a JVM à faixa
`[1.7,1.8)`. Depois de alterar somente essa política e configurar
`source/target` como 1.8, o build produziu bytecode Java 8 major `52`.

Isso comprova que a aplicação não está apenas executando um binário Java 7 em
uma JVM mais nova: o estado corrigido é efetivamente construído com Java 8.

### Configuração do runtime

O WildFly 9 distribuía `-XX:MaxPermSize=256m`, opção ignorada porque a geração
permanente foi removida no Java 8. A correção removeu somente essa flag da cópia
temporária do runtime usada no teste. Heap, portas, servidor, instalação
externa e demais opções permaneceram inalterados.

Isso comprova que a diferença de configuração da JVM foi identificada e
corrigida sem misturar a troca do Java com uma atualização do WildFly.

### Equivalência funcional

Os 14 contratos foram aprovados nos dois perfis. Eles exercitaram health,
listagem, criação e consulta de pedidos, sessão, upload, limite de tamanho,
formulário e importação XML, rejeições por XSD e validadores, XML hostil e
estado persistido.

O resultado demonstra equivalência funcional para o comportamento coberto
pelos contratos congelados na fase 1. Não foi necessário alterar Servlet, JSP,
JSTL, Tiles, FileUpload, XMLBeans, Reflections, Log4j ou o código de negócio
para recuperar esses fluxos no Java 8.

### Qualificação da persistência

O perfil H2 aprovou a trilha `portable-ci`, enquanto o Oracle Database 19c RU
19.3 aprovou separadamente a trilha `oracle-qualified`. Em ambos foram
exercitados o datasource `java:/jdbc/MigrationDS`, o pool gerenciado pelo
WildFly, os mappers e transações MyBatis e o estado persistido.

Isso comprova que, dentro do contrato do laboratório, H2 e Oracle continuam
funcionais no Java 8. O resultado H2 permanece apenas complementar e não é
tratado como substituto da qualificação Oracle.

### Isolamento da mudança

A árvore Maven preservou as mesmas 24 dependências e o mesmo SHA-256
`2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`
do baseline. O WAR manteve os mesmos 20 JARs em `WEB-INF/lib`, as APIs do
contêiner continuaram em `provided` e H2 e `ojdbc7` permaneceram fora do
artefato.

Maven continuou em 3.8.9, WildFly em 9.0.2.Final e os pacotes em `javax.*`.
Assim, as evidências isolam a mudança de JVM das atualizações de servidor,
ferramenta de build, especificação EE e dependências planejadas para os
checkpoints seguintes.

### Síntese

Para a aplicação do laboratório, a migração Java 7 para Java 8 exigiu somente:

1. atualizar a faixa de Java aceita pelo Maven Enforcer;
2. compilar com `source/target` 1.8;
3. remover do runtime Java 8 a opção obsoleta `MaxPermSize`.

Depois dessas correções, build, auditoria, contratos H2 e qualificação Oracle
foram aprovados. O CP-2A, portanto, demonstra uma modernização da JVM com baixo
impacto e fornece um procedimento reproduzível para investigar a mesma
transição em uma aplicação real.

### Limites da conclusão

O CP-2A não comprova automaticamente que qualquer aplicação real será
compatível. Antes de aplicar a mesma conclusão, a aplicação real precisa
executar seu WAR anterior no Java 8, ser recompilada e passar por todos os seus
fluxos, integrações, bibliotecas e configurações operacionais.

O checkpoint também não comprova:

- compatibilidade com WildFly 26, que será tratada no CP-2B;
- alinhamento com EE 8 ou Maven 3.9.16, reservado ao CP-2C;
- atualização ou segurança das bibliotecas históricas;
- desempenho, carga, cluster, sistemas operacionais ou integrações não
  exercitadas;
- adequação de Java 8 ou WildFly 9 como destino permanente de produção.

Cada checkpoint seguinte registrará sua conclusão somente depois de seus
próprios testes, no respectivo documento de evidência.

## Rollback

Use a tag `migration/01-legacy-baseline` e
[`legacy-baseline-reproduction.md`](../legacy-baseline-reproduction.md). O
rollback do código será um novo commit revertendo o squash do CP-2A; nenhum
dado fora do schema descartável do laboratório será removido.
