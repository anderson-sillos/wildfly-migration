# Aplicação evolutiva

Esta é a única árvore de código da aplicação do laboratório. Ela começa no
baseline legado e será alterada, na mesma linha Git, até o destino Jakarta EE
11. Estados anteriores serão preservados por commits e pelas três tags públicas,
não por cópias da aplicação em outros diretórios.

## Estrutura inicial

| Caminho | Responsabilidade |
| --- | --- |
| `src/main/java/` | código Java da aplicação |
| `src/main/resources/` | recursos empacotados e configurações da aplicação |
| `src/main/webapp/` | JSPs, conteúdo web e descritores |
| `src/main/webapp/WEB-INF/` | conteúdo protegido e descritores do WAR |
| `src/test/java/` | testes internos da aplicação |
| `src/test/resources/` | recursos dos testes internos |

O `pom.xml` e o empacotamento WAR entram no CP-1C. No CP-1B, este scaffold
contém somente o SQL Oracle, o XSD e a estrutura de fontes; ainda não há
dependências, binários, JARs manuais nem uma implementação funcional.
