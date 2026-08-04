# CP-3H / atividade 3.39 — auditoria final do empacotamento

## Escopo

Esta auditoria verifica o artefato efetivamente gerado no gate Jakarta/Java
21. Ela rejeita APIs fornecidas pelo WildFly dentro do WAR, Log4j 1 e pontes,
Tiles, Commons FileUpload 1, Reflections e scanners externos, `xml-apis`,
Geronimo StAX, `ojdbc7` e drivers H2/Oracle empacotados. Também valida que o
`ServletContainerInitializer` permaneça no JAR interno aprovado, com o
descritor `META-INF/services/jakarta.servlet.ServletContainerInitializer`, e
que os validators concretos permaneçam em `WEB-INF/classes`.

## Execução

Após um build limpo do WAR Jakarta:

```bash
./scripts/audit-cp-3h-final-packaging.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war \
  --write-evidence
```

O `--write-evidence` deve ser executado com a árvore Git limpa para que a
proveniência seja registrada como `workingTree=false`. Depois, a validação
reprodutível sem alterar a evidência é:

```bash
./scripts/audit-cp-3h-final-packaging.sh \
  --war app/target/cp3f-jakarta11/wildfly-migration.war
```

O resultado sanitizado fica em
`migration/evidence/CP-3H/packaging-audit.json`; ele contém apenas o commit, o
checksum do WAR e estados `passed`, sem URL ou credenciais Oracle.

## Rollback

A auditoria não executa DDL, altera o WAR ou instala módulos. Em caso de
falha, corrija o conteúdo do build ou retorne ao último commit verde do
CP-3H/3.38; o schema Oracle e os dados externos permanecem intactos.
