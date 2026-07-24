# Evidência CP-1A — Repositório GitHub e ambiente

## Escopo

- Repositório: <https://github.com/anderson-sillos/wildfly-migration>
- Visibilidade: pública
- Branch principal: `main`
- Branch de entrega: `checkpoint/cp-1a-repository-bootstrap`
- Commit-semente: `1a2b917` (`chore: seed OpenSpec migration plan`)
- Commit de entrega esperado:
  `checkpoint(CP-1A): bootstrap repository and environment`

O commit-semente contém somente o planejamento OpenSpec e as ferramentas que já
existiam antes do bootstrap. A documentação, o diagnóstico e a governança são
entregues separadamente pelo PR do CP-1A.

## Configuração GitHub

- [x] `main` como branch padrão.
- [x] Somente squash merge habilitado.
- [x] Exclusão automática da branch depois do merge.
- [x] Template de pull request e guia de contribuição.
- [ ] Verificação `repository-baseline` executada no PR.
- [ ] Proteção de `main` aplicada e consultada depois da primeira execução da CI.
- [ ] PR integrado por squash.

## Validações locais

Execute a partir da raiz:

```bash
bash -n scripts/doctor.sh
./scripts/doctor.sh CP-1A
./scripts/doctor.sh CP-1A --ci
openspec validate create-java-web-migration-lab \
  --type change --strict --no-interactive
```

Resultados esperados:

- sintaxe Bash válida;
- `doctor` sem falhas;
- requisitos futuros explicitamente marcados como não exigidos;
- change OpenSpec válida em modo estrito;
- nenhum arquivo de credencial ou binário restrito versionado.

## Reprodução por clone limpo

Após a integração do PR:

```bash
git clone https://github.com/anderson-sillos/wildfly-migration.git
cd wildfly-migration
bash -n scripts/doctor.sh
./scripts/doctor.sh CP-1A
```

Registrar aqui a URL do PR, a execução da CI, o commit squash e o resultado do
clone limpo antes de concluir a tarefa 1.5.

## Rollback

Antes do merge, basta fechar o PR e excluir a branch do checkpoint. Depois do
merge, crie um PR que reverta o commit squash do CP-1A; não force push em `main`
e não reescreva o commit-semente. A reversão remove somente o bootstrap e mantém
o planejamento OpenSpec disponível para uma nova tentativa.

## Segurança

- O remote usa HTTPS sem token embutido.
- A identidade Git é local ao repositório.
- Tokens não são mantidos em `.env` ou na documentação.
- Java 7u80, drivers Oracle, wallets e distribuições de runtime não fazem parte
  desta entrega.
