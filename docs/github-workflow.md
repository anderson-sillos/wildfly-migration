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

## Workflows de validação

O CI é separado por finalidade:

- `.github/workflows/validate.yml` executa `repository-baseline` em todo pull
  request e em todo push para `main`;
- `.github/workflows/portable.yml` executa `portable-ci` somente quando mudam
  configuração de exemplo, aplicação, contratos, baseline executável,
  runtimes, scripts ou o próprio workflow portátil.

Alterações exclusivamente em `docs/`, `openspec/` ou evidências já capturadas
continuam recebendo a validação estática, mas não recriam Java, Maven, WildFly,
H2 e o WAR. Uma alteração em `scripts/`, `runtime/`, `contract-tests/`,
`migration/baselines/`, `app/`, `.env.example` ou no workflow portátil sempre
executa a trilha H2 completa.

Os dois workflows agrupam execuções pelo nome do workflow e pela referência
Git. Quando um novo commit chega ao mesmo PR, a execução anterior ainda em
andamento é cancelada. Isso não cancela validações de outros PRs nem mistura
`repository-baseline` com `portable-ci`.

## Reutilização dos caches

As chaves de cache identificam o conteúdo reutilizável, não a atividade ou o
checkpoint consumidor. Isso evita downloads repetidos entre tarefas que usam
a mesma combinação:

```text
runtime-archives-v3-<sistema>-<arquitetura>-<hash-dos-manifestos>
maven-repository-v2-<sistema>-<arquitetura>-maven-<versão>-<hash-do-pom>
```

`v3` e `v2` são versões do formato das respectivas chaves. Elas só devem
mudar quando o layout ou a política do cache se tornar incompatível. O cache
de runtime usa os manifestos das distribuições aprovadas; o cache Maven usa a
versão efetiva da ferramenta e `app/pom.xml`.

Cada cache possui uma chave parcial de restauração. Quando apenas um manifesto
ou o POM muda, o job restaura a entrada compatível mais recente e baixa somente
o que estiver ausente. Os arquivos de runtime restaurados são sempre
revalidados pelos SHA-256 aprovados antes do uso.

Somente arquivos de distribuição externos e `~/.m2/repository` são
reutilizados. Configurações Maven, credenciais, `app/target`, relatórios,
evidências, cópias extraídas do WildFly e demais resultados continuam sendo
recriados em cada execução.

## Compatibilidade com tokens de instalação

O GitHub anunciou que tokens de instalação de GitHub Apps, incluindo o
`GITHUB_TOKEN` do Actions, passarão a poder usar o formato stateless `ghs_`,
com aproximadamente 520 caracteres e dois pontos internos:
<https://github.blog/changelog/2026-05-15-github-app-installation-tokens-per-request-override-header/>.

Os workflows deste projeto não criam tokens de instalação, não inspecionam
prefixo ou quantidade de pontos e não fazem suposição sobre tamanho. O token é
tratado como valor opaco pelas actions oficiais, com permissão mínima
`contents: read`. Como nenhum passo posterior executa `git push`, os checkouts
usam `persist-credentials: false`.

Tokens também não podem participar de chave, caminho ou conteúdo dos caches.
Os caches contêm somente distribuições públicas verificadas por checksum e o
repositório local de dependências Maven.

O header temporário `X-GitHub-Stateless-S2S-Token` só se aplica à chamada que
cria um token para uma instalação de GitHub App. Como o projeto não possui
essa integração, adicionar o header ao workflow não testaria o `GITHUB_TOKEN`
fornecido pelo próprio Actions. Se uma GitHub App for introduzida futuramente,
ela deverá testar os formatos `enabled` e `disabled`, aceitar pelo menos 520
caracteres e remover o override depois da validação recomendada pelo GitHub.
