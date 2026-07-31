# CP-3B — Atualização do MyBatis para 3.5.19

## Pré-condição

- commit verde do CP-3A:
  `6d94e5fc735575fa2ac644690a2a0635d921199f`;
- Java 17, WildFly 26.1.3 e Maven 3.9.16;
- H2 2.4.240 para `portable-ci`;
- Oracle Database 19c RU 19.3 e `ojdbc7` externo para a qualificação desta
  atividade, sem antecipar a troca de driver da atividade 3.14.

## Estado anterior

O WAR do CP-3A empacota `mybatis-3.4.5.jar`. Mappers XML, aliases, type
handlers e limites transacionais funcionam nos dois perfis, mas a versão não é
a aprovada para o destino.

## Alteração

O POM ativo fixa `org.mybatis:mybatis:3.5.19`. Uma allowlist própria do gate
Java 17 substitui somente o JAR MyBatis; as allowlists históricas permanecem
inalteradas.

Nenhum mapper, alias, type handler, repositório, SQL ou limite transacional é
reescrito. `logImpl` também não é alterado nesta atividade: a decisão de
logging pertence às atividades 3.7 e 3.34.

## Verificação

As duas trilhas executam:

1. auditoria da árvore Maven e de `WEB-INF/lib`;
2. carregamento dos dois mappers e dos dois aliases;
3. seleção dos type handlers de status e SHA-256;
4. acesso reflexivo a `Pedido.numero` com `MetaClass` e `MetaObject`;
5. commit de pedido e anexo e rollback de uma falha intencional;
6. os 14 contratos HTTP externos.

O Oracle adiciona round-trip de `TIMESTAMP(6)` e BLOB. A conclusão e os
checksums observados são registrados em `docs/evidence/CP-3B.md` depois da
execução.

## Rollback

Retornar ao commit do CP-3A restaura MyBatis 3.4.5 sem modificar o schema:

```bash
git switch --detach 6d94e5fc735575fa2ac644690a2a0635d921199f
```
