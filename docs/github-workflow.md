# Fluxo GitHub

## Repositório aprovado

| Propriedade | Valor |
| --- | --- |
| Resource owner | `anderson-sillos` |
| Repositório | `wildfly-migration` |
| Visibilidade | público |
| Branch principal | `main` |
| URL | <https://github.com/anderson-sillos/wildfly-migration> |

Cada checkpoint usa `checkpoint/*`; a integração é feita por pull request com
squash merge. O remote local deve usar HTTPS sem credencial embutida:

```bash
git remote add origin https://github.com/anderson-sillos/wildfly-migration.git
git remote -v
```

Tokens são fornecidos somente pela sessão ou pelo armazenamento seguro de
credenciais e nunca aparecem na URL do `origin`.

## Bootstrap do histórico

Para o CP-1A:

```bash
git push -u origin main
git switch -c checkpoint/cp-1a-repository-bootstrap
git push -u origin checkpoint/cp-1a-repository-bootstrap
```

## Configuração do repositório

Habilite somente squash merge, apague branches integradas automaticamente e
mantenha issues conforme a decisão do projeto:

```bash
gh api --method PATCH repos/anderson-sillos/wildfly-migration \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true
```

Proteja `main` com o melhor nível permitido pelo plano da conta:

- pull request obrigatório;
- verificação `repository-baseline` obrigatória;
- conversas resolvidas antes do merge;
- histórico linear;
- bloqueio de force push e exclusão;
- ao menos uma aprovação quando houver outro revisor disponível.

Em um repositório pessoal sem segundo revisor, não configure uma regra que torne
o primeiro PR impossível de integrar. Registre a limitação na evidência do
checkpoint e mantenha PR, CI, squash e histórico linear.

## Pull request de checkpoint

Cada PR deve:

- declarar exatamente um ID de checkpoint;
- relacionar tarefas concluídas e fora de escopo;
- anexar comandos e resultados de validação sem segredos;
- explicar rollback e limitações;
- passar por `repository-baseline` e pelas verificações adicionadas depois;
- produzir no squash o assunto `checkpoint(<ID>): <entrega>`.

Somente os finais das três fases públicas recebem tags. Gates Java 17 e Java 21
da fase 3 ficam identificados por commits e manifestos, sem tags públicas.
