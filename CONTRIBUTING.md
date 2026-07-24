# Contribuição

O laboratório usa uma branch, um pull request e um commit squash por checkpoint.
Não acumule tarefas de checkpoints diferentes no mesmo PR.

## Fluxo

1. Atualize `main`.
2. Crie `checkpoint/<id-em-minusculas>-<descricao-curta>`, por exemplo
   `checkpoint/cp-1b-legacy-runtime`.
3. Implemente somente as tarefas do checkpoint ativo.
4. Execute o `doctor`, os testes e as auditorias já disponíveis.
5. Registre evidências reproduzíveis e instruções de rollback sem segredos.
6. Abra o PR usando o template do repositório.
7. Faça squash merge somente depois das verificações obrigatórias.

O commit produzido no branch principal usa:

```text
checkpoint(<ID>): <entrega>
```

Exemplo:

```text
checkpoint(CP-1A): bootstrap repository and environment
```

## Validação mínima

No CP-1A:

```bash
bash -n scripts/doctor.sh
./scripts/doctor.sh CP-1A
```

Nos checkpoints seguintes, selecione explicitamente o checkpoint para que apenas
os requisitos já aplicáveis sejam exigidos:

```bash
./scripts/doctor.sh CP-2C
```

## Conteúdo proibido

Não adicione:

- `.env` ou qualquer arquivo com credenciais;
- wallets, chaves, certificados privados ou tokens;
- JDK 7u80, `ojdbc7` ou outros binários proprietários;
- distribuições Java, Maven ou WildFly;
- JARs manuais em `WEB-INF/lib`;
- evidências que reproduzam senhas, URLs sensíveis ou tokens.

Se um segredo for incluído, interrompa a publicação, revogue ou rotacione o
valor e siga [SECURITY.md](SECURITY.md).
