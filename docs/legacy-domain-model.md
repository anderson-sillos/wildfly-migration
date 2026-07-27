# Modelo mínimo do laboratório

O laboratório usa um domínio pequeno para ativar persistência, sessão, upload e
XML sem transformar a migração em um projeto funcional amplo. Nomes HTTP,
campos persistidos e namespace XML definidos aqui permanecem estáveis entre as
três fases.

## Pedido

| Campo | Tipo lógico | Regra |
| --- | --- | --- |
| `id` | inteiro de 64 bits | Gerado por sequence Oracle; não vem do cliente |
| `numero` | texto, 1–32 | Obrigatório e único; identificador funcional estável |
| `clienteNome` | texto, 1–120 | Obrigatório |
| `descricao` | texto, 0–500 | Opcional |
| `valorTotal` | decimal, 15/2 | Obrigatório e maior ou igual a zero |
| `status` | enum | `NOVO`, `APROVADO` ou `CANCELADO` |
| `criadoEm` | timestamp | Definido pelo servidor |
| `atualizadoEm` | timestamp | Definido pelo servidor |

O contrato compara valores monetários com duas casas decimais. Datas são
persistidas como `TIMESTAMP(6)` e só serão convertidas para um fuso na borda
HTTP; essa decisão permite observar diferenças de driver sem esconder o valor
armazenado.

## Anexo

| Campo | Tipo lógico | Regra |
| --- | --- | --- |
| `id` | inteiro de 64 bits | Gerado por sequence Oracle |
| `pedidoId` | inteiro de 64 bits | Pedido existente; remoção em cascata não é implícita |
| `nomeArquivo` | texto, 1–255 | Somente nome normalizado, sem caminho do cliente |
| `tipoConteudo` | texto, 1–127 | Tipo informado após normalização |
| `tamanhoBytes` | inteiro de 64 bits | Entre zero e o limite do upload |
| `sha256` | hexadecimal, 64 | Digest do conteúdo recebido |
| `conteudo` | binário | BLOB usado para exercitar o contrato Oracle |
| `criadoEm` | timestamp | Definido pelo servidor |

O nome original bruto nunca é usado como caminho. O limite de upload será
fixado no checkpoint que implementar o fluxo, mas o tamanho e o digest já fazem
parte do contrato comparável.

## Preferência de sessão

`modoExibicao` existe somente em `HttpSession` e aceita `COMPACTO` ou
`DETALHADO`. O valor padrão é `DETALHADO`; valores desconhecidos voltam ao
padrão. A preferência não é persistida no Oracle e não altera regras de negócio,
apenas a quantidade de detalhes exibida nas páginas.

O fixture
[`preferencia-detalhada.json`](../contract-tests/fixtures/session/preferencia-detalhada.json)
representa a forma normalizada observada pelos testes HTTP.

## Recursos versionados

- DDL Oracle idempotente:
  [`001_schema.sql`](../app/src/main/resources/db/oracle/001_schema.sql);
- massa mínima idempotente:
  [`002_seed.sql`](../app/src/main/resources/db/oracle/002_seed.sql);
- limpeza reversível:
  [`rollback.sql`](../app/src/main/resources/db/oracle/rollback.sql);
- scripts H2 equivalentes e exclusivos do CI:
  [`db/h2/`](../app/src/main/resources/db/h2/);
- matriz de diferenças H2/Oracle:
  [`h2-oracle-differences.md`](h2-oracle-differences.md);
- contrato XML:
  [`pedido-importacao-v1.xsd`](../app/src/main/resources/xsd/pedido-importacao-v1.xsd);
- fixtures XML:
  [`contract-tests/fixtures/xml/`](../contract-tests/fixtures/xml/).

Os scripts usam comandos compatíveis com SQL*Plus/SQLcl. Cada bloco PL/SQL deve
ser terminado por `/` em uma linha separada. Os scripts H2 são independentes,
validados contra o mesmo contrato lógico e nunca substituem a qualificação
Oracle.
