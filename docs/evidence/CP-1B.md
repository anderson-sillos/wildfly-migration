# Evidência CP-1B — Estrutura e runtime legado

## Escopo

- Branch de entrega: `checkpoint/cp-1b-legacy-runtime`;
- commit de entrega esperado:
  `checkpoint(CP-1B): scaffold legacy runtime`;
- árvore única da aplicação: `app/`;
- áreas auxiliares: `contract-tests/`, `runtime/`, `migration/steps/` e `docs/`;
- nenhuma cópia paralela da aplicação, `pom.xml`, WAR ou dependência Maven
  pertence a este checkpoint.

## Runtime externo aprovado

Os arquivos e diretórios extraídos permanecem em `/opt/migration-lab`, fora do
checkout e do Git. A origem, licença e os digests que o `doctor` usa como
autoridade estão em `runtime/legacy/runtime-manifest.tsv`.

| Componente | Versão efetiva | Arquivo | SHA-256 |
| --- | --- | --- | --- |
| Oracle JDK | `1.7.0_80-b15`, HotSpot 64-bit `24.80-b11` | `jdk-7u80-linux-x64.tar.gz`, 153.530.841 bytes | `bad9a731639655118740bee119139c1ed019737ec802a630dd7ad7aab4309623` |
| Apache Maven | `3.8.9` | `apache-maven-3.8.9-bin.tar.gz`, 8.296.518 bytes | `3e4c68cdd70f96635e713f36c8fc3ea3182035245d3da2156576710ca0fe4b0c` |
| WildFly Full | `9.0.2.Final`, Core `1.0.2.Final` | `wildfly-9.0.2.Final.tar.gz`, 135.659.070 bytes | `74689569d6e04402abb7d94921c558940725d8065dce21a2d7194fa354249bb6` |

O JDK foi fornecido manualmente depois de autenticação e aceite da licença
Oracle. Seu arquivo passou por `gzip -t`, possui raiz única `jdk1.7.0_80/`, não
contém caminho absoluto ou componente `..` e declarou Linux amd64/build
comercial. A Oracle não publica um digest para esse download histórico; o
SHA-256 acima identifica o arquivo licenciado efetivamente aprovado pelo
laboratório.

O SHA-512 publicado pela Apache para o Maven também foi conferido:

```text
4a490b7f331a0e7869b61da24600241e445339f2801ed94e32f835b63ed78597ad05ef8c1cce2501b4c2c3dcde30030eb395cd5756be739c20ac687ad6f82f0e
```

Maven 3.8.9 foi executado com `JAVA_HOME` apontando para o JDK 7u80 e relatou
`Java version: 1.7.0_80, vendor: Oracle Corporation`.

## Recursos estáticos

- SQL Oracle 19c idempotente para pedido e anexo, massa mínima e rollback;
- XSD versionado para importação de pedido;
- XML válido e inválido por schema;
- fixtures hostis para XXE e expansão de entidades;
- preferência de sessão normalizada;
- validador JAXP compilável para Java 7, sem dependência adicional.

O validador confirmou que o XML legítimo atende ao XSD, o documento inválido é
rejeitado e os dois documentos hostis falham no `DOCTYPE` antes de qualquer
resolução externa.

## Validações

Execute a partir da raiz:

```bash
bash -n scripts/doctor.sh scripts/validate-cp-1b.sh
./scripts/validate-cp-1b.sh --release
./scripts/doctor.sh CP-1A --ci
./scripts/doctor.sh CP-1B --env .env
openspec validate create-java-web-migration-lab \
  --type change --strict --no-interactive
git diff --check
```

Resultados observados:

- estrutura e recursos estáticos do CP-1B aprovados;
- manifesto de release sem valores pendentes;
- XSD e fixtures XML aprovados;
- `doctor` CP-1B com 41 verificações aprovadas, nenhuma falha ou aviso e oito
  itens de checkpoints futuros marcados como não exigidos;
- Java 7u80, Maven 3.8.9 e WildFly 9.0.2.Final aprovados por versão, origem,
  licença e checksum;
- bind legado restrito a loopback e portas válidas;
- Docker daemon e autenticação GitHub acessíveis no host;
- change OpenSpec válida em modo estrito;
- nenhum erro de whitespace.

O `doctor` precisa acessar o Docker daemon e a rede usada pela GitHub CLI. Uma
execução em sandbox pode reprovar apenas esses dois itens; a evidência de
fechamento deve vir da execução no host, que foi aprovada.

## Reprodução a partir de checkout limpo

Em 24 de julho de 2026, a branch foi clonada em um diretório temporário sem
arquivos não versionados. Nesse clone:

- o commit e o worktree estavam limpos;
- shell, estrutura, manifesto, SQL, XSD, fixtures e OpenSpec passaram;
- o primeiro `doctor` integral identificou, como esperado, que a identidade Git
  não acompanha um clone;
- depois do bootstrap documentado de `user.name` e `user.email`, o `doctor`
  repetiu o resultado de 41 verificações aprovadas, nenhuma falha ou aviso;
- os runtimes foram reutilizados somente por caminhos externos informados em
  um arquivo de ambiente ignorado, sem copiar artefatos para o checkout.

Procedimento reproduzível:

1. Clone o commit da branch ou do PR em um diretório temporário.
2. Configure a identidade Git e siga `docs/environment-setup.md` e
   `runtime/legacy/README.md`.
3. Crie um `.env` local a partir de `.env.example`, usando os caminhos externos
   aprovados.
4. Execute a sequência de validações acima.

O clone não contém e não baixa automaticamente o JDK, os arquivos Maven/WildFly,
os diretórios extraídos ou credenciais. O mesmo `/opt/migration-lab` pode ser
referenciado pelo `.env` do clone sem copiar esses componentes para o Git.

## Rollback

Antes do merge, feche o PR e remova apenas a branch
`checkpoint/cp-1b-legacy-runtime`. Depois do merge, abra um PR que reverta o
commit squash do CP-1B; não reescreva `main`.

Os arquivos externos não são removidos pelo rollback Git. Se a limpeza local for
necessária, confirme os três caminhos exatos sob `/opt/migration-lab` e remova
somente:

```text
/opt/migration-lab/tools/jdk1.7.0_80
/opt/migration-lab/tools/apache-maven-3.8.9
/opt/migration-lab/tools/wildfly-9.0.2.Final
```

Os arquivos em `/opt/migration-lab/archives` podem ser preservados para
reprodução. Nunca use o caminho amplo `/opt/migration-lab` como alvo de remoção
recursiva.

## Segurança e limitações

- Java 7u80 e os runtimes EOL são exclusivos do laboratório local.
- Nenhuma porta legada é publicada em interface externa.
- O JDK, cookies Oracle, credenciais, wallets, drivers e `.env` não são
  versionados nem enviados como artefatos de CI.
- O Oracle Database ainda não é exigido no CP-1B e será validado a partir do
  CP-1D.
- O WAR e as dependências da aplicação começam no CP-1C.
