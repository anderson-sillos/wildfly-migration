# Runtime Java 8/WildFly 26

O CP-2B troca somente o servidor da aplicação aprovada no CP-2A. Java,
Maven, dependências, bytecode, namespace `javax.*` e contrato funcional
permanecem inalterados durante a primeira tentativa.

## Distribuição fixada

- release:
  <https://github.com/wildfly/wildfly/releases/tag/26.1.3.Final>;
- arquivo:
  <https://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.tar.gz>;
- tamanho: `216801297` bytes;
- checksum SHA-1 publicado pelo release:
  `b9f52ba41df890e09bb141d72947d2510caf758c`;
- SHA-256 fixado pelo laboratório:
  `aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59`;
- licença da distribuição comunitária: `LGPL-2.1-or-later`;
- ciclo de vida no laboratório: ponte EOL, nunca destino permanente.

Valide o arquivo antes de extraí-lo fora do checkout:

```bash
sha1sum /opt/migration-lab/archives/wildfly-26.1.3.Final.tar.gz
sha256sum /opt/migration-lab/archives/wildfly-26.1.3.Final.tar.gz
tar -xzf /opt/migration-lab/archives/wildfly-26.1.3.Final.tar.gz \
  -C /opt/migration-lab/tools
```

Configure somente no `.env` ignorado:

```dotenv
MIGRATION_CHECKPOINT=CP-2B
WILDFLY26_HOME=/opt/migration-lab/tools/wildfly-26.1.3.Final
WILDFLY26_ARCHIVE=/opt/migration-lab/archives/wildfly-26.1.3.Final.tar.gz
WILDFLY26_ARCHIVE_SHA256=aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59
```

O manifesto desta pasta é a fonte legível por máquina. Os binários e as
cópias temporárias do servidor não são versionados.

## Primeira tentativa

O WAR aprovado no CP-2A foi copiado sem modificação para uma base temporária
criada a partir do `standalone.xml` original da distribuição. Nenhum driver,
datasource, módulo ou configuração da aplicação foi migrado antes do teste.

O WildFly iniciou em loopback, mas o deployment ficou `FAILED` porque
`java:/jdbc/MigrationDS` não existe na configuração original. A evidência está
em
[`migration/evidence/CP-2B/before-deployment.properties`](../../../migration/evidence/CP-2B/before-deployment.properties).

## Configuração corrigida

Use `scripts/smoke-wildfly26-datasource.sh`. O wrapper fixa Java 8/WildFly 26
e reutiliza o ciclo seguro de cópia temporária, sanitização e limpeza do
runtime anterior. Os arquivos em `profiles/` tratam a diferença do modelo de
datasource sem alterar os perfis do WildFly 9.

A distribuição instalada em `/opt` nunca é modificada. HTTPS e os recursos de
keystore padrão são removidos somente da cópia temporária porque o laboratório
expõe apenas HTTP e management em loopback.
