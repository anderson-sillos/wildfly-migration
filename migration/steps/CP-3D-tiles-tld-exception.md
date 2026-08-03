# CP-3D — exceção temporária de Tiles e TLD

## Tentativa e decisão

O CP-3D inicia sobre o WAR aprovado no CP-3C, em Java 17/WildFly 26.1.3 e
Jakarta EE 8 (`javax`). A atividade 3.16 não atualiza Tiles: a linha 2.1.4 é
mantida porque o projeto está descontinuado e outra linha EOL não seria uma
correção de compatibilidade. A migração de namespace e a troca arquitetural
ficam isoladas nos gates Jakarta.

## Verificação reproduzível

```bash
./scripts/validate-cp-3d-tiles-tld.sh
```

O script confirma POM, allowlist, `web.xml`, `tiles-defs.xml`, TLD 2.0 e o
handler `javax.servlet.jsp.tagext`, além de rejeitar versões Tiles diferentes
ou referências Jakarta antecipadas. A execução não inicia servidor nem acessa
Oracle; os contratos de runtime serão executados na atividade 3.17.

## Aplicação equivalente no sistema real

Congele o inventário efetivo e o comportamento do layout, registre a exceção
como temporária e associe a substituição a uma janela específica da migração
Jakarta. Não aceite uma atualização de Tiles apenas para remover o alerta de
versão se ela continuar descontinuada.

## Próxima decisão e rollback

O TLD será capturado antes da normalização na atividade 3.28 e o layout será
substituído na 3.31. Até lá, o rollback técnico é o commit integrado do CP-3C;
nenhuma limpeza de banco faz parte desta atividade.

