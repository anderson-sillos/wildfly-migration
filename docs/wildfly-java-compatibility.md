# Evolução da compatibilidade entre WildFly e Java SE

Este quadro é uma referência histórica para planejar a migração do laboratório.
Ele considera a distribuição **padrão e comunitária** do WildFly e foi
verificado em **30 de julho de 2026**. Consulte sempre as notas da versão exata
antes de usar a tabela como critério de produção.

## Como interpretar

- **Sim**: combinação na qual o projeto WildFly declara suporte, executa testes
  fortes ou informa que o servidor funciona bem, mas sem destacar esse JDK como
  o preferido da linha. Todos os campos `Sim` têm exatamente esse significado;
- **Rec.**: atende a tudo que `Sim` representa e, adicionalmente, identifica o
  JDK escolhido pelo WildFly como preferido naquela linha;
- **Aval.**: executa bem segundo o projeto, mas ainda estava em avaliação ou sem
  toda a qualificação usada para recomendá-la;
- **N/Q**: combinação não qualificada ou não documentada para aquela linha; não
  significa que toda tentativa de inicialização necessariamente falhará;
- **Não**: versão explicitamente removida ou inferior ao requisito mínimo;
- **LTS**: *Long-Term Support* (suporte de longo prazo), versão Java destinada a
  receber manutenção por mais tempo que as versões não LTS; a duração efetiva
  depende da distribuição do JDK;
- **EOL**: *End of Life* (fim do ciclo de vida), situação em que uma versão ou
  build encerrou seu fluxo regular de manutenção e atualizações pelo responsável.
  A existência e o alcance de suporte comercial de terceiros devem ser
  verificados separadamente.

A indicação do JDK para executar o servidor e a declaração formal de
compatibilidade Jakarta EE são avaliações diferentes. A primeira decorre dos
testes de runtime do WildFly. A segunda exige executar e publicar os resultados
do **TCK** (*Technology Compatibility Kit*), o conjunto oficial de testes de
conformidade, para uma combinação específica de WildFly e JDK. Portanto, um JDK
pode ser o runtime recomendado sem constar na declaração TCK daquela plataforma.

Na geração EE 8, a mudança de nome também não representa uma mudança de
namespace: Java EE 8 e Jakarta EE 8 oferecem APIs idênticas em pacotes
`javax.*`. Portanto, uma linha cuja certificação publicada é “Jakarta EE 8”
continua compatível, no nível dessas APIs, com aplicações Java EE 8. A ruptura
de namespace para `jakarta.*` acontece depois, a partir do Jakarta EE 9.

## Ciclo de manutenção das distribuições Java

O ciclo de vida não pertence apenas ao número da versão Java SE: ele depende da
distribuição e do fornecedor das atualizações. O quadro abaixo usa as
distribuições de referência deste projeto e a disponibilidade publicada pelo
fornecedor em **30 de julho de 2026**.

| Java SE | Distribuição de referência | Situação | Disponibilidade de atualizações |
|---|---|---|---|
| 7 | Oracle JDK 7u80 e Zulu/OpenJDK 7u352 fixados no projeto | **EOL para as builds fixadas** | Sem fluxo de atualização aprovado; o 7u80 encerrou as atualizações públicas da Oracle |
| 8 | Eclipse Temurin | LTS mantida | Pelo menos até dezembro de 2030 |
| 11 | Eclipse Temurin | LTS mantida, com janela menor | Pelo menos até outubro de 2027 |
| 17 | Eclipse Temurin | LTS mantida, com janela menor | Pelo menos até outubro de 2027 |
| 21 | Eclipse Temurin | LTS mantida | Pelo menos até dezembro de 2029 |
| 25 | Eclipse Temurin | LTS mantida | Pelo menos até setembro de 2031 |

Para o Java 7, a indicação EOL se limita às builds históricas fixadas pelo
projeto; ela não pretende representar contratos comerciais de outros
fornecedores. Para Java 8 ou superior, as datas são a disponibilidade mínima
publicada pelo Eclipse Temurin e devem ser verificadas novamente antes de uma
decisão de produção. Uma JVM mantida também não torna seguro um servidor ou uma
aplicação que permaneça sem correções.

## Ciclo de manutenção do WildFly comunitário

O projeto WildFly não publica uma matriz formal de EOL nem oferece uma linha
LTS comunitária. Seu modelo normal prevê uma versão principal aproximadamente
a cada trimestre e uma correção micro por versão. A ausência de um EOL formal
não significa que uma linha antiga continue recebendo correções.

| WildFly | Estado em 30/07/2026 | EOL formal publicado | Manutenção comunitária | Orientação para produção real |
|---|---|---|---|---|
| 8–39 | Substituídos | Não | Sem linha regular de correções; exceções são pontuais | Não adotar em novas implantações; planejar a migração das instalações existentes |
| 40 | Substituído pelo 41 | Não | Ciclo curto de correção micro, sem manutenção LTS | Não adotar como nova base; atualizar para a linha atual |
| 41 | Versão atual | Não anunciado | Linha corrente, também sujeita ao ciclo trimestral e curto | Pode ser usado se a organização aceitar suporte comunitário e mantiver atualização contínua |

Para produção, a decisão não deve se limitar ao servidor iniciar ou à aplicação
passar nos testes. É necessário avaliar vulnerabilidades, dependências,
capacidade de atualizar frequentemente e exigências de SLA. Quando suporte
contratual ou manutenção LTS forem obrigatórios, o WildFly comunitário sozinho
não satisfaz esse requisito e uma oferta com suporte deve ser avaliada
separadamente.

## Matriz de compatibilidade

| WildFly | Java 7 | Java 8 | Java 11 | Java 17 | Java 21 | Java 25 | Plataforma padrão e compatibilidade de aplicação¹ |
|---|---:|---:|---:|---:|---:|---:|---|
| 8–9 | Sim | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7 |
| 10–13 | Não | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7; EE 8 disponível em modo de prévia no 13 |
| 14 | Não | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 8 |
| 15–24 | Não | Sim | Rec. | N/Q² | N/Q | N/Q | Java EE 8; também Jakarta EE 8 a partir do 17.0.1 |
| 25–26.1³ | Não | Sim | Sim | Sim | N/Q | N/Q | **Java EE 8 / Jakarta EE 8** (APIs `javax.*`) |
| 27–29 | Não | Não | Sim | Rec. | N/Q | N/Q | Jakarta EE 10 |
| 30–31 | Não | Não | Sim | Rec. | Aval. | N/Q | Jakarta EE 10 |
| 32 | Não | Não | Sim | Sim | Rec.⁴ | N/Q | Jakarta EE 10 |
| 33–34 | Não | Não | Sim | Sim | Rec. | N/Q | Jakarta EE 10 |
| 35–37 | Não | Não | Não | Sim | Rec. | N/Q | Jakarta EE 10 |
| 38–39 | Não | Não | Não | Sim | Rec. | Aval. | Jakarta EE 10 |
| 40 | Não | Não | Não | Sim | Sim | Rec.⁵ | Jakarta EE 11; variante EE 10 temporária |
| 41 | Não | Não | Não | Sim | Sim | Rec.⁵ | Jakarta EE 11; variante EE 10 temporária |

1. A coluna mostra a plataforma da distribuição padrão. WildFly Preview e a
   variante temporária WildFly EE 10 dos releases 40–41 têm objetivos diferentes.
2. O WildFly Preview 24 já permitia avaliar Java 17, mas a distribuição padrão
   24 não executava bem em Java 14 ou superior. O suporte forte a Java 17 chegou
   à distribuição padrão no WildFly 25.
3. No WildFly 25–26.1, o projeto recomendava executar o servidor em um JDK LTS
   e não escolhia uma única versão preferencial entre Java 8, 11 e 17. As três
   eram fortemente testadas; Java 8 e 11 possuíam o maior histórico acumulado de
   testes. Nenhuma recebe `Rec.` porque nenhuma foi escolhida sobre as demais.
   Esse caso é único na matriz. WildFly 8–9 também possui mais de um `Sim` sem
   `Rec.`, mas apenas documentava compatibilidade e incentivava interessados em
   Java 8 a utilizá-lo. No WildFly 10–14, Java 8 era requisito ou a única opção
   qualificada, não uma preferência entre vários JDKs compatíveis.
4. No WildFly 32, Java 21 já era o JDK preferido e possuía certificação Jakarta
   EE 10 Core Profile. A certificação Full Platform e Web Profile nesse JDK foi
   publicada a partir do WildFly 33.
5. WildFly 40 e 41 escolhem Java 25 como runtime preferido; Java 17 e 21
   permanecem compatíveis. Os resultados TCK publicados para Jakarta EE 11 usam
   Java 17 e 21. Portanto, `Rec.` no Java 25 expressa preferência de runtime,
   não uma declaração TCK nesse JDK.

### O que foi comprovado no WildFly 26.1

Há duas comprovações complementares, que não devem ser confundidas:

1. **Projeto WildFly:** a distribuição padrão 26.1 é certificada como Jakarta
   EE 8 Full Platform e Web Profile e suporta execução nos JDKs 8, 11 e 17.
   Como Jakarta EE 8 mantém as APIs Java EE 8 em `javax.*`, aplicações Java EE
   8 permanecem compatíveis no nível dessas APIs.
2. **Atividade 3.1 do laboratório:** o WAR imutável da fase 2, compilado para
   Java 8 e baseado em EE 8/`javax.*`, foi implantado sem correção no Java
   17/WildFly 26.1.3 e aprovou os 14 contratos H2. Isso comprova a
   compatibilidade de execução portátil **desta aplicação**, sem substituir a
   certificação da plataforma nem qualificar o comportamento Oracle.

A atividade 3.2 ampliou a evidência ao recompilar os mesmos fontes para Java 17
e aprovar novamente os 14 contratos. Consulte a
[evidência do CP-3A](evidence/CP-3A.md) para os limites exatos.

## Aplicação no roteiro do laboratório

O quadro explica os três pontos usados no projeto:

1. o baseline reproduz WildFly 9 com Java 7, combinação que forma o ponto
   inicial explícito da matriz;
2. a ponte de baixo impacto usa WildFly 26.1.3 com Java 8, mantendo a aplicação
   Java EE 8 sobre a plataforma Jakarta EE 8 de APIs `javax.*`, e depois
   reaproveita o mesmo servidor no gate Java 17;
3. o destino entra no WildFly 41 com Java 21 para isolar a migração Jakarta EE
   11 e troca somente a JVM para Java 25 no gate final.

Esses pontos são checkpoints do laboratório, não uma recomendação para iniciar
novos projetos em versões históricas. Consulte o
[mapa de checkpoints](checkpoints.md) e a
[preparação do ambiente](environment-setup.md) para as versões exatas,
checksums e critérios de validação.

Nesse roteiro, “ponte” descreve exclusivamente uma estratégia incremental de
migração para reduzir mudanças simultâneas. Não é uma classificação oficial do
WildFly nem altera o ciclo de manutenção registrado no quadro complementar: o
WildFly 26.1.3 requer um plano explícito de saída quando usado temporariamente
em uma aplicação real.

## Fontes primárias

- [Ciclo de suporte e disponibilidade do Eclipse Temurin](https://adoptium.net/support/);
- [Oracle JDK 7: fim das atualizações públicas após o 7u80](https://www.oracle.com/java/technologies/javase/7u-relnotes.html);
- [Oracle Java Archive: builds antigas não são recomendadas para produção](https://www.oracle.com/java/technologies/downloads/archive/);
- [Downloads oficiais: WildFly 41 é a versão atual](https://www.wildfly.org/downloads/);
- [WildFly 8: Java EE 7 e compatibilidade com Java 8](https://www.wildfly.org/news/2014/02/12/WildFly-8-Final-is-released/);
- [WildFly 9: Java EE 7](https://www.wildfly.org/news/2015/07/02/WildFly-9-Final-is-released/);
- [WildFly 10: Java 7 descontinuado e Java 8 como requisito](https://www.wildfly.org/news/2016/01/30/WildFly-10-Final-is-now-available/);
- [WildFly 13: Java EE 7 padrão e EE 8 em modo de prévia](https://www.wildfly.org/news/2018/05/31/WildFly-13-Baker-s-Dozen-is-released/);
- [WildFly 14: certificação Java EE 8](https://www.wildfly.org/news/2018/08/30/WildFly-14-is-released/);
- [WildFly 15: início da recomendação de Java 11](https://www.wildfly.org/news/2018/12/13/WildFly-15-is-released/);
- [WildFly 17.0.1: certificação Jakarta EE 8](https://www.wildfly.org/news/2019/09/12/WildFly-is-Jakarta-EE-8-Certified/);
- [WildFly 18: Java EE 8, Jakarta EE 8 e APIs idênticas](https://www.wildfly.org/news/2019/10/03/WildFly-18-is-released/);
- [WildFly 24: Java 8/11 e limite da distribuição padrão no Java 17](https://www.wildfly.org/news/2021/06/17/WildFly-24-is-released/);
- [WildFly 25: recomendação dos JDKs LTS e suporte a Java 8/11/17](https://www.wildfly.org/news/2021/10/05/WildFly-25-is-released/);
- [WildFly 26.1: Jakarta EE 8 e recomendação dos JDKs LTS 8/11/17](https://www.wildfly.org/news/2022/04/14/WildFly-26-1-is-released/);
- [WildFly 27: Java 11/17 e Jakarta EE 10](https://www.wildfly.org/news/2022/11/09/WildFly-27-Final-is-released/);
- [WildFly 30: Java 21 em avaliação e Core Profile](https://www.wildfly.org/news/2023/10/18/WildFly-30-is-released/);
- [WildFly 32: Java 21 recomendado](https://www.wildfly.org/news/2024/04/25/WildFly-32-is-released/);
- [WildFly 33: Jakarta EE 10 Full/Web em Java 21](https://www.wildfly.org/news/2024/07/23/WildFly-33-is-released/);
- [WildFly 35: Java 17 mínimo e remoção de Java 11](https://www.wildfly.org/news/2024/10/28/WildFly-35-moves-to-SE-17-drops-SE-11/);
- [WildFly 38: Java 25 em avaliação](https://www.wildfly.org/news/2025/10/16/WildFly-38-is-released/);
- [WildFly 39: Java 17/21 e avaliação de Java 25](https://www.wildfly.org/news/2026/01/16/WildFly-39-is-released/);
- [WildFly 40: Jakarta EE 11 e Java 25 recomendado](https://www.wildfly.org/news/2026/05/21/WildFly-40-is-released/);
- [WildFly 41: runtime atual e matriz Java 17/21/25](https://www.wildfly.org/news/2026/07/16/WildFly-41-is-released/);
- [Modelo de releases comunitárias e correções micro](https://www.wildfly.org/news/2023/05/11/WildFly-Release-Plans/);
- [Prática de não manter regularmente linhas antigas](https://www.wildfly.org/news/2023/01/18/WildFly-26-1-3-is-released/).
