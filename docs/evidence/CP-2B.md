# Evidência CP-2B — WildFly 26 no Java 8

## Escopo

- estado verde de origem: CP-2A, commit
  `bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`;
- WAR de origem:
  `bb6caddd16d36028ef8547398634c6e6fbf0de389d7a63b5c5f803a3409a53e4`;
- destino: Eclipse Temurin OpenJDK 8u492-b09 e WildFly comunitário
  26.1.3.Final;
- configuração de destino: `standalone.xml` original, sem datasource
  `MigrationDS`;
- alterações de código, POM, dependências e WAR antes da tentativa: nenhuma.

## Tentativa antes da correção

O WAR copiado para a base temporária preservou exatamente o SHA-256 aprovado
no CP-2A. O servidor confirmou `WildFly Full 26.1.3.Final`, iniciou em
loopback e manteve o processo em estado `running`, porém com erros de serviço.

O CLI retornou:

```text
wildfly-migration.war  FAILED
WFLYCTL0216: Management resource data-source=MigrationDS not found
```

O endpoint `/wildfly-migration/health` respondeu `404`, pois o contexto web
não ficou ativo. A assinatura determinante no log foi:

```text
javax.naming.NameNotFoundException:
jdbc/MigrationDS -- service jboss.naming.context.java.jdbc.MigrationDS
```

A aplicação converteu a falha em
`IllegalStateException: Datasource JNDI do laboratório não está disponível`;
nenhuma URL, credencial ou endereço Oracle foi registrado.

## Observações preliminares

| Área | Resultado anterior à correção |
| --- | --- |
| Configuração | O `standalone.xml` original inicia, mas não contém os recursos do laboratório. |
| Datasource | Bloqueante: `java:/jdbc/MigrationDS` ausente impede o bootstrap MyBatis. |
| Segurança | Elytron gerou apenas avisos do keystore temporário padrão; nenhuma falha de segurança da aplicação foi alcançada. |
| Logging | `WFLYLOG0100`: `log4j.properties` foi aceito, porém seu suporte está depreciado. |
| Classloader | Tiles alcançou sua inicialização e avisou sobre factories opcionais de portlet; a falha JNDI interrompeu a validação funcional completa. |

Essa tabela registra o que foi efetivamente observado, mas não encerra a
tarefa 2.7. A ausência do datasource mascara possíveis problemas posteriores;
eles serão classificados antes da configuração corretiva.

## Evidência legível por máquina

O registro sanitizado está em
[`before-deployment.properties`](../../migration/evidence/CP-2B/before-deployment.properties).
O log bruto permaneceu apenas na área temporária local e não foi versionado.

## Próxima correção

Provisionar os perfis H2 e Oracle no WildFly 26 sob
`java:/jdbc/MigrationDS`, preservando schema, código, namespace e WAR. A
correção ainda não faz parte desta evidência.
