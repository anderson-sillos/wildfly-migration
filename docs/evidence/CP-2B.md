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

## Classificação das incompatibilidades

| Área | Resultado anterior à correção |
| --- | --- |
| Configuração | Bloqueante | O `standalone.xml` original inicia, mas contém somente `ExampleDS`; os recursos do laboratório não migram com a troca do binário. |
| Datasource | Bloqueante, `INC-007` | `java:/jdbc/MigrationDS` ausente impede o bootstrap MyBatis e deixa o deployment `FAILED`. |
| Segurança | Não bloqueante, `INC-009` | Elytron tenta gerar o keystore HTTPS padrão; a aplicação não possui `security-constraint`, `login-config` ou domínio próprio. O runtime do laboratório removerá o listener HTTPS desnecessário. |
| Logging | Não bloqueante, `INC-008` | `WFLYLOG0100`: `log4j.properties` foi aceito, porém seu suporte está depreciado. A remoção da biblioteca permanece adiada para o gate de dependências. |
| Classloader | Nenhuma quebra confirmada | Não houve `ClassNotFoundException`, `NoClassDefFoundError` ou `LinkageError`. Tiles avisou sobre factories opcionais de portlet e Weld sobre ausência de bean archive; não será incluído JAR nem `beans.xml` apenas para silenciar avisos. |

A classificação legível por máquina está em
[`compatibility-observations.tsv`](../../migration/evidence/CP-2B/compatibility-observations.tsv).
A falha JNDI limita a profundidade da observação do classloader; os contratos
das tarefas 2.8 e 2.9 deverão confirmar que nenhuma quebra aparece depois da
ativação do contexto.

Ao iniciar a correção, a aplicação direta do arquivo CLI do WildFly 9 revelou
`INC-010`: o WildFly 26 rejeita o argumento `pool-name` na operação
`data-source:add`. A correção mantém perfis próprios por servidor e remove
somente esse atributo redundante.

## Evidência legível por máquina

O registro sanitizado está em
[`before-deployment.properties`](../../migration/evidence/CP-2B/before-deployment.properties).
O log bruto permaneceu apenas na área temporária local e não foi versionado.

## Próxima correção

Provisionar os perfis H2 e Oracle no WildFly 26 sob
`java:/jdbc/MigrationDS`, preservando schema, código, namespace e WAR. A
correção ainda não faz parte desta evidência.
