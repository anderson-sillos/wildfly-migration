# INC-007 — WildFly 26 não contém o datasource do laboratório

## Identificação

- checkpoint: `CP-2B`;
- estado verde de origem: commit
  `bce4fb90b85301a0f2dd60c46f0ec5f6a96ff7a0`;
- runtime de destino: Java 8/WildFly 26.1.3.Final;
- etapa: `deployment`;
- categoria: configuração de datasource;
- reprodução: `natural`;
- estado: aberto.

## Tentativa antes da correção

O mesmo WAR aprovado no CP-2A foi copiado para uma base temporária criada a
partir da configuração original da distribuição WildFly 26. Nenhum módulo,
driver ou datasource do laboratório foi adicionado.

## Assinatura sanitizada

```text
javax.naming.NameNotFoundException:
jdbc/MigrationDS -- service jboss.naming.context.java.jdbc.MigrationDS
```

O CLI confirmou deployment `FAILED`, ausência do recurso
`data-source=MigrationDS` e resposta HTTP `404` para o health check.

## Causa-raiz

O datasource é configuração gerenciada do servidor e não faz parte do WAR.
Atualizar somente o binário do WildFly não transfere módulos, drivers,
datasources, pool, validações ou credenciais do WildFly 9.

## Menor correção planejada

Criar na cópia temporária do WildFly 26 o driver correspondente ao perfil e o
datasource `java:/jdbc/MigrationDS`, preservando código, POM, schema e contrato
funcional. H2 e Oracle continuarão configurações separadas.

## Evidências antes e depois

- antes:
  [`before-deployment.properties`](../evidence/CP-2B/before-deployment.properties);
- depois: será preenchido nas tarefas 2.8 e 2.9.

## Aplicação equivalente no sistema real

Inventarie a configuração do servidor anterior e migre explicitamente
driver, módulo, JNDI, pool, validação de conexão e segredo externo. Não copie
o diretório inteiro do WildFly antigo para a instalação nova.

## Teste de regressão planejado

O CLI deverá retornar datasource habilitado, `test-connection-in-pool`
aprovado, deployment `OK` e health HTTP `200` nos dois perfis.

## Rollback

Pare e descarte somente a base temporária do WildFly 26. O commit do CP-2A e
sua instalação WildFly 9 permanecem o último estado verde.
