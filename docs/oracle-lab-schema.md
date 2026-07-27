# Aprovação do schema Oracle do laboratório

O laboratório usa Oracle Database 19c RU 19.3 (`19.3.0.0.0`). A URL e a
credencial configuradas comprovam conectividade, mas isso não torna o schema
automaticamente descartável. A execução de DDL, DML e rollback Oracle exige
evidência técnica e autorização administrativa.

## Criação pelo DBA

No Oracle, o schema é criado junto com o usuário que o possui. A criação
abaixo é exclusiva para laboratório; ela deve ser executada por um DBA, nunca
com a credencial da aplicação.

1. Escolha um PDB/serviço **não produtivo** e um tablespace permanente próprio
   para testes ou já aprovado pelo DBA. Não use `CDB$ROOT`, `SYSTEM` nem
   `SYSAUX`.
2. Conecte a sessão administrativa diretamente ao serviço desse PDB e confirme
   o container antes de criar qualquer conta:

   ```sql
   SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS container_atual
   FROM dual;
   ```

3. Defina o nome local da conta, a quota e uma senha gerada. A senha deve ser
   transmitida por canal seguro e não deve ser salva em script, histórico,
   evidência ou repositório. Exemplo a ser adaptado pelo DBA:

   ```sql
   CREATE USER MIGRATION_LAB
     IDENTIFIED BY "SENHA_GERADA_FORA_DESTE_SCRIPT"
     DEFAULT TABLESPACE USERS
     TEMPORARY TABLESPACE TEMP
     QUOTA 100M ON USERS
     CONTAINER = CURRENT;
   ```

   `USERS`, `TEMP`, `100M` e `MIGRATION_LAB` são exemplos, não valores
   obrigatórios. A quota deve comportar os BLOBs dos testes, mas continuar
   limitada.

4. Conceda somente os privilégios necessários para a conta criar os quatro
   objetos do laboratório e abrir sessão:

   ```sql
   GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE
   TO MIGRATION_LAB;
   ```

   Não conceda `DBA`, `RESOURCE`, `CONNECT`, `UNLIMITED TABLESPACE` nem
   privilégios contendo `ANY`.

5. Conecte com a nova conta e confirme identidade, PDB, quota, privilégios e
   ausência de objetos:

   ```sql
   SELECT
     USER AS usuario_sessao,
     SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual,
     SYS_CONTEXT('USERENV', 'CON_NAME') AS container_atual,
     SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS servico
   FROM dual;

   SELECT tablespace_name, bytes, max_bytes
   FROM user_ts_quotas
   ORDER BY tablespace_name;

   SELECT privilege
   FROM session_privs
   ORDER BY privilege;

   SELECT granted_role
   FROM user_role_privs
   ORDER BY granted_role;

   SELECT object_type, object_name
   FROM user_objects
   ORDER BY object_type, object_name;
   ```

6. O DBA registra, sem revelar os valores, que a conta é exclusiva, o PDB é
   não produtivo, o schema começou vazio e pode ser eliminado ao fim do
   laboratório.
7. Somente então configure `ORACLE_DB_URL`, `ORACLE_DB_USER` e
   `ORACLE_DB_PASSWORD` no `.env` local ignorado pelo Git e execute primeiro o
   `doctor` e o smoke de conexão, que não fazem DDL.
8. Após uma segunda confirmação do alvo, aplique como dono do schema:

   ```bash
   ./scripts/oracle-lab-schema.sh inspect --env .env
   ./scripts/oracle-lab-schema.sh apply --env .env
   ```

   O wrapper valida o alvo sem registrar credenciais e aplica
   `001_schema.sql`/`002_seed.sql` por JDBC. Se preferir SQL*Plus, os mesmos
   arquivos podem ser executados manualmente com `@arquivo`.

9. Use `rollback.sql` para reiniciar apenas os quatro objetos `LAB_*`. Para
   desativar definitivamente a conta, o DBA deve primeiro bloqueá-la e depois,
   com confirmação específica do nome, removê-la:

   ```sql
   ALTER USER MIGRATION_LAB ACCOUNT LOCK;
   DROP USER MIGRATION_LAB CASCADE;
   ```

   `DROP USER ... CASCADE` remove todo o schema e é irreversível; não faz parte
   de nenhum smoke automatizado.

## Verificações somente leitura

Execute conectado com a mesma credencial configurada no perfil `oracle`:

```sql
SELECT
  USER AS usuario_sessao,
  SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') AS schema_atual,
  SYS_CONTEXT('USERENV', 'CON_NAME') AS container_atual,
  SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS servico
FROM dual;

SELECT object_type, object_name
FROM user_objects
ORDER BY object_type, object_name;

SELECT privilege
FROM session_privs
ORDER BY privilege;

SELECT granted_role
FROM user_role_privs
ORDER BY granted_role;
```

Não publique serviço, host, usuário ou qualquer valor da conexão. Registre
somente a aprovação dos critérios.

## Critérios de aprovação

Todos os itens abaixo precisam ser verdadeiros:

1. usuário da sessão e schema atual correspondem à conta dedicada ao
   laboratório;
2. o DBA confirma que o serviço/container e o schema podem receber dados de
   teste e ser limpos;
3. `USER_OBJECTS` não contém objetos de outra aplicação;
4. objetos existentes com prefixo `LAB_` pertencem somente a uma execução
   anterior deste laboratório e podem ser removidos;
5. a sessão não possui papel `DBA` nem privilégios `DROP ANY TABLE`,
   `ALTER ANY TABLE`, `DELETE ANY TABLE` ou equivalentes amplos;
6. a conta pode criar tabelas e sequences no próprio schema;
7. nenhum consumidor externo utiliza `LAB_PEDIDO`, `LAB_ANEXO`,
   `LAB_PEDIDO_SEQ` ou `LAB_ANEXO_SEQ`.

Uma consulta não consegue provar sozinha que um ambiente é descartável. A
confirmação explícita do responsável pelo banco continua obrigatória mesmo
quando todos os resultados técnicos parecem adequados.

## Escopo destrutivo

O `rollback.sql` Oracle remove somente:

- `LAB_ANEXO`;
- `LAB_PEDIDO`;
- `LAB_ANEXO_SEQ`;
- `LAB_PEDIDO_SEQ`.

As tabelas são removidas com `PURGE`. Essa operação não pode ser desfeita e não
mantém as tabelas na recycle bin. A qualificação Oracle não será executada
enquanto os critérios acima não forem aprovados.

Referências oficiais:

- [Oracle 19c — SYS_CONTEXT](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/SYS_CONTEXT.html);
- [Oracle 19c — SESSION_PRIVS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/SESSION_PRIVS.html);
- [Oracle 19c — USER_ROLE_PRIVS](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/USER_ROLE_PRIVS.html);
- [Oracle 19c — DROP TABLE](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DROP-TABLE.html);
- [Oracle 19c — criar contas de usuário](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/creating-user-accounts.html);
- [Oracle 19c — remover contas de usuário](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/dropping-user-accounts.html).
