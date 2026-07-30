# Evolução da compatibilidade entre WildFly e Java SE

Este quadro é uma referência histórica para planejar a migração do laboratório.
Ele considera a distribuição **padrão e comunitária** do WildFly e foi
verificado em **30 de julho de 2026**. Consulte sempre as notas da versão exata
antes de usar a tabela como critério de produção.

## Como interpretar

- **Rec.**: JDK LTS recomendado pelo projeto naquela linha;
- **Sim**: versão suportada, fortemente testada ou descrita como executando bem;
- **Aval.**: executa bem segundo o projeto, mas ainda estava em avaliação ou sem
  toda a qualificação usada para recomendá-la;
- **N/Q**: combinação não qualificada ou não documentada para aquela linha; não
  significa que toda tentativa de inicialização necessariamente falhará;
- **Não**: versão explicitamente removida ou inferior ao requisito mínimo.

“Compatibilidade do runtime” e “compatibilidade Jakarta EE comprovada por TCK”
não são sinônimos. Por exemplo, o WildFly 41 recomenda Java 25 e é fortemente
testado nesse JDK, mas a declaração publicada de compatibilidade Jakarta EE 11
é para Java 17 e Java 21.

## Quadro revisado

| WildFly | Situação comunitária¹ | Java 8 | Java 11 | Java 17 | Java 21 | Java 25 | Plataforma padrão² |
|---|---|---:|---:|---:|---:|---:|---|
| 8–9 | Histórica | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7 |
| 10–13 | Histórica | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 7; EE 8 disponível em modo de prévia no 13 |
| 14 | Histórica | Sim | N/Q | N/Q | N/Q | N/Q | Java EE 8 |
| 15–24 | Histórica | Sim | Rec. | N/Q³ | N/Q | N/Q | Java EE 8; também Jakarta EE 8 a partir do 17.0.1 |
| 25–26.1 | Histórica | Sim | Sim | Sim | N/Q | N/Q | Jakarta EE 8 |
| 27–29 | Histórica | Não | Sim | Rec. | N/Q | N/Q | Jakarta EE 10 |
| 30–31 | Histórica | Não | Sim | Rec. | Aval. | N/Q | Jakarta EE 10 |
| 32 | Histórica | Não | Sim | Sim | Rec.⁴ | N/Q | Jakarta EE 10 |
| 33–34 | Histórica | Não | Sim | Sim | Rec. | N/Q | Jakarta EE 10 |
| 35–37 | Histórica | Não | Não | Sim | Rec. | N/Q | Jakarta EE 10 |
| 38–39 | Histórica | Não | Não | Sim | Rec. | Aval. | Jakarta EE 10 |
| 40 | Histórica | Não | Não | Sim | Sim | Rec.⁵ | Jakarta EE 11; variante EE 10 temporária |
| 41 | **Atual** | Não | Não | Sim | Sim | Rec.⁵ | Jakarta EE 11; variante EE 10 temporária |

1. **Situação comunitária:** “histórica” indica que uma versão mais nova já a
   substituiu e que não há uma linha regular de manutenção de longo prazo
   prometida pelo projeto. O WildFly normalmente publica uma versão principal
   por trimestre e uma única correção micro; em geral, não continua corrigindo
   linhas antigas depois de uma nova versão principal ou secundária. Isso não é
   uma declaração formal de EOL e não deve ser confundido com o ciclo comercial
   do JBoss EAP.
2. A coluna mostra a plataforma da distribuição padrão. WildFly Preview e a
   variante temporária WildFly EE 10 dos releases 40–41 têm objetivos diferentes.
3. O WildFly Preview 24 já permitia avaliar Java 17, mas a distribuição padrão
   24 não executava bem em Java 14 ou superior. O suporte forte a Java 17 chegou
   à distribuição padrão no WildFly 25.
4. No WildFly 32, Java 21 já era o JDK recomendado e possuía certificação
   Jakarta EE 10 Core Profile. A certificação Full Platform e Web Profile em
   Java 21 foi publicada a partir do WildFly 33.
5. WildFly 40 e 41 recomendam Java 25 e executam bem em Java 17, 21 e 25.
   Entretanto, a declaração Jakarta EE 11 publicada cobre Java 17 e 21, não
   Java 25.

## Aplicação no roteiro do laboratório

O quadro explica os três pontos usados no projeto:

1. o baseline reproduz WildFly 9 com Java 7; Java 7 não foi acrescentado como
   coluna porque o quadro solicitado começa no Java 8;
2. a ponte de baixo impacto usa WildFly 26.1.3 com Java 8 e depois reaproveita
   o mesmo servidor no gate Java 17;
3. o destino entra no WildFly 41 com Java 21 para isolar a migração Jakarta EE
   11 e troca somente a JVM para Java 25 no gate final.

Esses pontos são checkpoints do laboratório, não uma recomendação para iniciar
novos projetos em versões históricas. Consulte o
[mapa de checkpoints](checkpoints.md) e a
[preparação do ambiente](environment-setup.md) para as versões exatas,
checksums e critérios de validação.

## Fontes primárias

- [Downloads oficiais: WildFly 41 é a versão atual](https://www.wildfly.org/downloads/);
- [WildFly 8: Java EE 7 e compatibilidade com Java 8](https://www.wildfly.org/news/2014/02/12/WildFly-8-Final-is-released/);
- [WildFly 9: Java EE 7](https://www.wildfly.org/news/2015/07/02/WildFly-9-Final-is-released/);
- [WildFly 13: Java EE 7 padrão e EE 8 em modo de prévia](https://www.wildfly.org/news/2018/05/31/WildFly-13-Baker-s-Dozen-is-released/);
- [WildFly 14: certificação Java EE 8](https://www.wildfly.org/news/2018/08/30/WildFly-14-is-released/);
- [WildFly 15: início da recomendação de Java 11](https://www.wildfly.org/news/2018/12/13/WildFly-15-is-released/);
- [WildFly 17.0.1: certificação Jakarta EE 8](https://www.wildfly.org/news/2019/09/12/WildFly-is-Jakarta-EE-8-Certified/);
- [WildFly 24: Java 8/11 e limite da distribuição padrão no Java 17](https://www.wildfly.org/news/2021/06/17/WildFly-24-is-released/);
- [WildFly 25: suporte a Java 8, 11 e 17](https://www.wildfly.org/news/2021/10/05/WildFly-25-is-released/);
- [WildFly 26.1: última linha com Java 8 e Jakarta EE 8](https://www.wildfly.org/news/2022/04/14/WildFly-26-1-is-released/);
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
