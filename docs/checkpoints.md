# Checkpoints

O `doctor` aceita os checkpoints abaixo e acumula apenas os requisitos que já
entraram na linha evolutiva.

| Fase | Checkpoint | Entrega mínima |
| --- | --- | --- |
| 1 | CP-1A | GitHub, governança, documentação e diagnóstico |
| 1 | CP-1B | Estrutura única e runtime Java 7/WildFly 9 |
| 1 | CP-1C | WAR e dependências legadas |
| 1 | CP-1D | Fundação portátil H2 e qualificação Oracle |
| 1 | CP-1E | Fluxo web e persistência |
| 1 | CP-1F | Upload, XML, descoberta e contratos |
| 1 | CP-1G | Baseline completo e tag da fase 1 |
| 2 | CP-2A | Java 8 no WildFly 9 |
| 2 | CP-2B | Migração do runtime para WildFly 26 |
| 2 | CP-2C | EE 8, Maven 3.9.16 e datasource |
| 2 | CP-2D | Fechamento e tag da fase 2 |
| 3 | CP-3A | Entrada no Java 17 |
| 3 | CP-3B | Dependências centrais |
| 3 | CP-3C | XML e Oracle JDBC |
| 3 | CP-3D | Gate Java 17 |
| 3 | CP-3E | Entrada no WildFly 41 com Java 21 |
| 3 | CP-3F | Namespace e descritores Jakarta |
| 3 | CP-3G | Substituições web |
| 3 | CP-3H | Oracle e auditoria final |
| 3 | CP-3I | Gate Java 21 |
| 3 | CP-3J | Qualificação OpenJDK 25 |
| 3 | CP-3K | Destino final e tag da fase 3 |

O relatório consolidado do destino final está em
[`evidence/CP-3K.md`](evidence/CP-3K.md), e as lições aprendidas estão na
[conclusão do projeto](project-conclusion.md). O CP-3K encerra a fase 3 depois
da aprovação das atividades 3.53 a 3.55.

As tags públicas são:

- `migration/01-legacy-baseline`;
- `migration/02-java8-wildfly26`;
- `migration/03-final`.

Cada fechamento registra preparação, comandos, versões detectadas, evidências,
cenários não executados, limitações e rollback. Evidências nunca contêm
credenciais ou binários restritos.
