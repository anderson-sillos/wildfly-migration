# Operação e testes manuais da aplicação legada

Este é o ponto único para preparar, construir, iniciar, verificar e encerrar a
aplicação da fase 1 no Java 7 e WildFly 9. Os documentos especializados
explicam versões e decisões; os comandos operacionais ficam aqui.

## Escopo atual

O CP-1E disponibiliza:

- health check;
- listagem, criação e detalhe de pedidos;
- persistência MyBatis pelo datasource `java:/jdbc/MigrationDS`;
- JSP/JSTL, Tiles 2.1.4 e TLD 2.0;
- preferência de exibição em `HttpSession`;
- upload por Commons FileUpload 1.2.2 com limites e metadados SHA-256;
- filtro UTF-8 e cabeçalho `X-Correlation-ID`.

Importação XML, Reflections e uso funcional do Log4j entram nos próximos
incrementos do CP-1F e ainda não fazem parte dos testes manuais.

## Escolha do perfil

| Perfil | Use quando | Estado dos dados | Qualificação |
| --- | --- | --- | --- |
| `ci-h2` | teste local portátil e CI, sem Oracle | H2 em memória; desaparece no stop | somente `portable-ci` |
| `oracle` | host autorizado na rede interna | schema Oracle descartável; persiste após o stop | `oracle-qualified` |

Os dois perfis usam o mesmo WAR, o mesmo JNDI e as mesmas URLs. H2 não comprova
compatibilidade Oracle. O perfil não é armazenado no `.env`: a partir do
`CP-1D`, informe sempre `--profile ci-h2` ou `--profile oracle` na linha de
comando.

## Pré-requisitos

1. Prepare as ferramentas e o `.env` conforme
   [Preparação do ambiente](environment-setup.md).
2. Mantenha Java, Maven, WildFly, H2 e `ojdbc7` fora do checkout.
3. Não execute `source .env`: os scripts leem somente as chaves permitidas sem
   executar o conteúdo do arquivo.
4. Não exponha o runtime legado fora de `127.0.0.1`.

O `.env` deve selecionar portas locais livres. O exemplo do projeto usa:

```text
LAB_BIND_ADDRESS=127.0.0.1
WILDFLY_HTTP_PORT=18080
WILDFLY_MANAGEMENT_PORT=19990
```

Não copie para documentação, terminal compartilhado ou issue os valores
`ORACLE_DB_URL`, `ORACLE_DB_USER` ou `ORACLE_DB_PASSWORD`.

## 1. Diagnosticar o ambiente

Escolha um perfil e execute o diagnóstico antes do build.

### H2

```bash
./scripts/doctor.sh CP-1E --profile ci-h2 --env .env
```

Esse perfil exige o Zulu OpenJDK 7u352 e o H2 1.4.200 fixados no manifesto
portátil. Ele não exige Oracle JDK, `ojdbc7` ou credenciais.

### Oracle

```bash
./scripts/doctor.sh CP-1E --profile oracle --env .env
```

Esse perfil exige Oracle JDK 7u80, truststore atualizado, `ojdbc7` aprovado e
configuração Oracle. O diagnóstico informa somente presença e validade; não
imprime os valores.

Pare se o resumo apresentar falhas. Itens de checkpoints futuros marcados
como `NÃO EXIGIDO` não impedem a fase 1.

## 2. Preparar o banco

### H2

Não há preparação manual. Ao iniciar o perfil `ci-h2`, o script cria schema e
seed dentro do processo H2 e recusa esse bootstrap se o produto conectado não
for H2.

### Oracle

O DBA deve ter aprovado um schema descartável conforme
[Aprovação do schema Oracle](oracle-lab-schema.md). Para um schema novo:

```bash
./scripts/oracle-lab-schema.sh inspect --env .env
./scripts/oracle-lab-schema.sh apply --env .env
./scripts/oracle-lab-schema.sh verify --env .env
```

`apply` cria somente:

- `LAB_PEDIDO`;
- `LAB_ANEXO`;
- `LAB_PEDIDO_SEQ`;
- `LAB_ANEXO_SEQ`;
- seed `LAB-0001`.

Não prossiga se `inspect` rejeitar identidade, PDB, quota, privilégios ou
objetos existentes. Nenhum comando de inicialização executa `DROP USER` ou
`rollback.sql`.

## 3. Construir e auditar o WAR

### H2

```bash
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
```

### Oracle

```bash
./scripts/build-cp-1d.sh --profile oracle --env .env
```

O nome histórico `build-cp-1d.sh` foi preservado porque o wrapper nasceu com a
fundação dos dois perfis. Ele sempre constrói o conteúdo atual de `app/`,
inclusive o CP-1E.

O resultado esperado é:

```text
app/target/wildfly-migration.war
```

O build também audita bytecode Java 7, dependências, APIs `provided`, ausência
de H2/`ojdbc7` no WAR e a lista esperada de `WEB-INF/lib`.

## 4. Iniciar para teste manual

O comando abaixo:

1. cria uma cópia temporária e limpa do WildFly;
2. provisiona o driver do perfil;
3. publica `java:/jdbc/MigrationDS`;
4. liga HTTP e management somente em loopback;
5. implanta o WAR;
6. executa o smoke inicial;
7. mantém a aplicação ativa até `Ctrl+C`.

Use um terminal dedicado.

### H2

```bash
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war \
  --manual
```

### Oracle

```bash
./scripts/smoke-wildfly9-datasource.sh \
  --profile oracle \
  --env .env \
  --war app/target/wildfly-migration.war \
  --manual
```

O terminal imprime as URLs efetivas a partir de `WILDFLY_HTTP_PORT`. Com a
porta de exemplo `18080`:

- lista: <http://127.0.0.1:18080/wildfly-migration/pedidos>;
- novo pedido: <http://127.0.0.1:18080/wildfly-migration/pedidos/novo>;
- saúde: <http://127.0.0.1:18080/wildfly-migration/health>.

O servidor permanece no primeiro terminal. Use outro terminal ou navegador
para os passos seguintes.

### Acompanhar o log do WildFly

No modo `--manual`, o script também imprime o caminho exato do log bruto e um
comando pronto para acompanhá-lo. O diretório temporário muda a cada execução:

```text
Log bruto do WildFly:
  Arquivo: /tmp/wildfly-migration-datasource.<identificador>/server.log
  Acompanhar: tail -f -- /tmp/wildfly-migration-datasource.<identificador>/server.log
```

Copie o comando `tail -f --` exibido no seu terminal e execute-o em outro
terminal. Não tente deduzir o `<identificador>`.

O arquivo existe somente enquanto a sessão manual está ativa. Ao pressionar
`Ctrl+C`, o script encerra o WildFly e remove o runtime temporário junto com o
`server.log`.

No perfil `oracle`, o `server.log` é bruto e pode conter host, serviço, usuário
ou URL interna. Revise e sanitize o conteúdo antes de copiar, anexar ao PR ou
publicar. Os diagnósticos de falha impressos pelo próprio script continuam
sanitizados.

## 5. Checklist de testes manuais

### Saúde e correlação

```bash
curl --include \
  http://127.0.0.1:18080/wildfly-migration/health
```

Confirme:

- HTTP `200`;
- corpo `status=UP`;
- cabeçalho `X-Correlation-ID` preenchido.

Se a porta no `.env` não for `18080`, ajuste as URLs dos exemplos.

### Listagem e Tiles/TLD

1. Abra `/wildfly-migration/pedidos`.
2. Confirme o pedido `LAB-0001`.
3. Confirme cabeçalho, conteúdo e rodapé do layout.
4. Confirme o status visual `Novo`, produzido pela tag customizada.

### Criação e detalhe

1. Abra `/wildfly-migration/pedidos/novo`.
2. Informe um número que não exista, cliente, descrição e valor decimal.
3. Envie o formulário.
4. Confirme o redirecionamento para o detalhe.
5. Confirme número, cliente, descrição, valor e status `Novo`.
6. Retorne à lista e confirme o novo registro.

No Oracle, use um prefixo identificável para dados manuais, por exemplo
`MANUAL-`. O stop remove apenas registros automáticos `LAB-SMOKE-*`; pedidos
criados manualmente permanecem no schema.

### Preferência em sessão

1. Na lista, altere a exibição de `Detalhada` para `Compacta`.
2. Navegue para outra página e volte à lista no mesmo navegador.
3. Confirme que a preferência continua `Compacta`.
4. Abra uma janela privada para confirmar que uma nova sessão volta ao padrão
   `Detalhada`.

### Upload

1. Abra o detalhe de um pedido.
2. Na seção `Anexos`, escolha um arquivo de até 512 KiB.
3. Confirme a mensagem de sucesso após o redirecionamento.
4. Compare na tabela nome normalizado, tipo, número de bytes e SHA-256.
5. Tente um arquivo maior que 512 KiB e confirme HTTP `413` com erro controlado.

O fluxo e os limites estão detalhados em
[Upload legado do CP-1F](legacy-upload.md). Não use dados sensíveis: o
laboratório persiste o conteúdo integral no BLOB.

### Erros controlados

Confirme que as respostas não exibem URL ou credenciais:

```bash
curl --include \
  "http://127.0.0.1:18080/wildfly-migration/pedidos/detalhe?id=invalido"

curl --include \
  "http://127.0.0.1:18080/wildfly-migration/pedidos/recurso-inexistente"
```

O primeiro caso deve retornar HTTP `400`; o segundo, HTTP `404`. Ambos devem
usar a página de erro controlado e apresentar uma correlação.

## 6. Encerrar

No terminal em que o servidor está ativo, pressione:

```text
Ctrl+C
```

O handler encerra o WildFly e remove somente sua cópia temporária.

| Perfil | Resultado do stop |
| --- | --- |
| `ci-h2` | runtime temporário e banco em memória são eliminados |
| `oracle` | runtime temporário é eliminado; objetos, seed e pedidos manuais permanecem |

Sinais `HUP`, `INT` e `TERM` também acionam a limpeza. Não use `kill -9`, pois
ele impede o handler de finalizar o runtime.

## 7. Limpeza e reinicialização

### Dados automáticos Oracle

O start e o stop limpam pedidos cujo número começa por `LAB-SMOKE-`. Para
executar a mesma limpeza explicitamente:

```bash
./scripts/oracle-lab-schema.sh cleanup-smokes --env .env
./scripts/oracle-lab-schema.sh verify --env .env
```

### Reiniciar todo o schema Oracle

`rollback.sql` remove permanentemente as duas tabelas e duas sequences. Execute
somente depois de reconfirmar o schema com o DBA, seguindo a seção destrutiva
de [Aprovação do schema Oracle](oracle-lab-schema.md). Depois, execute `apply`
novamente.

O projeto nunca automatiza `DROP USER ... CASCADE`.

### Derivados Maven

O próximo wrapper de build executa `clean` automaticamente. Não remova o
checkout nem o diretório externo amplo de ferramentas para limpar um teste.

## 8. Validação automatizada sem sessão manual

Remova `--manual` para executar o mesmo provisionamento, smoke e limpeza sem
manter o servidor ativo:

```bash
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war
```

O equivalente Oracle usa `--profile oracle`. Esse modo é o utilizado nas
evidências do CP-1E; ele não abre uma sessão para exploração pelo navegador.

## 9. Diagnóstico de falhas

| Sintoma | Verificação |
| --- | --- |
| Java portátil ou H2 obrigatório | confira `JAVA7_PORTABLE_HOME`, `H2_JAR` e checksums no `.env` |
| Java 7u80 ou `ojdbc7` obrigatório | execute o `doctor` com perfil `oracle` |
| porta já ocupada | altere `WILDFLY_HTTP_PORT` e `WILDFLY_MANAGEMENT_PORT` para duas portas locais livres |
| datasource não conecta | execute primeiro o smoke sem `--war`; no Oracle, valide a rota interna |
| `status=DOWN` ou HTTP 503 | confirme schema/seed e `java:/jdbc/MigrationDS` |
| deploy reclama de `ExampleDS` | confirme que `ci-h2.cli` reaponta `DefaultDataSource` para `MigrationDS` |
| página JSP/Tiles ou upload falha | reconstrua o WAR e confirme as 20 bibliotecas auditadas, incluindo `commons-io-1.3.2.jar` |

O script sanitiza diagnósticos Oracle. Não publique logs brutos do WildFly
antes de revisar a presença de host, serviço, usuário ou URL interna.

## Referências

- [Índice da documentação](README.md);
- [preparação e downloads](environment-setup.md);
- [runtime legado e checksums](../runtime/legacy/README.md);
- [perfis do datasource](../runtime/legacy/profiles/README.md);
- [persistência MyBatis](mybatis-persistence.md);
- [upload legado](legacy-upload.md);
- [diferenças H2/Oracle](h2-oracle-differences.md);
- [evidência do CP-1E](evidence/CP-1E.md).
