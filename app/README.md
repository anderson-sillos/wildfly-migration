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

O CP-1C adiciona o `pom.xml`, um marcador compilável e o descritor Servlet 2.4.
O WAR ainda não implementa o fluxo funcional, que começa no CP-1D.

Build legado:

```bash
./scripts/build-cp-1c.sh --env .env
```

O wrapper exige Maven 3.8.9 executando no Java 7u80, mantém o acesso ao Maven
Central sob TLS validado e audita o WAR. As dependências e transitivas aprovadas
estão em [`docs/legacy-dependencies.md`](../docs/legacy-dependencies.md).

Nenhum JAR manual, driver Oracle, runtime ou arquivo gerado em `target/` deve
ser versionado.
