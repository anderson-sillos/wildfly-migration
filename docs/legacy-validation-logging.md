# Descoberta e logging legados

O CP-1F reproduz dois acoplamentos da aplicação histórica:

- Reflections 0.9.10 descobre implementações de
  `PedidoImportValidator` no classloader do WAR;
- Log4j 1.2.14 registra eventos do fluxo XML com o identificador de correlação
  mantido em MDC.

Essas versões são deliberadamente antigas e ficam restritas ao laboratório em
loopback ou rede interna. Não são uma recomendação para produção.

## Contrato dos validadores

O conjunto e a ordem congelados são:

| Ordem | Identificador | Implementação |
| --- | --- | --- |
| 10 | `numero-formato` | confirma o formato do número do pedido |
| 20 | `valor-monetario` | confirma sinal, precisão e escala do valor |
| 30 | `status-inicial` | exige status `NOVO` em toda importação |

O Reflections localiza os subtipos; `LegacyValidatorDiscovery` ordena por
`order()` e, em caso de empate, pelo nome completo da classe. Identificadores
vazios ou duplicados e conjunto vazio interrompem a inicialização.

Para adicionar um validador no legado, crie uma classe pública concreta com
construtor sem argumentos, implemente `PedidoImportValidator`, escolha ordem e
identificador únicos e atualize o contrato automatizado. A tarefa final de
migração substituirá essa descoberta por registro explícito preservando o
mesmo conjunto e a mesma ordem.

O XSD aceita `NOVO`, `APROVADO` e `CANCELADO` porque descreve todos os estados
persistidos. A importação, porém, só pode criar pedidos em `NOVO`. Essa
diferença intencional permite comprovar que o documento passou pelo XSD,
chegou ao validador descoberto e foi rejeitado por regra de negócio.

## Logging e dados permitidos

`RequestContextFilter` coloca somente o `X-Correlation-ID` validado no MDC e o
remove em `finally`. O fluxo XML registra os eventos `started`, `accepted`,
`rejected` com categoria de motivo e `persistence_failure`.

Rejeições funcionais esperadas, como limite excedido, XML inválido ou regra de
domínio, são registradas sem stack trace. Falhas internas consumidas pela
fronteira HTTP e falhas de limpeza temporária registram o `Throwable` completo
uma única vez. Assim, o log preserva stack trace, causas e exceções suprimidas
sem duplicar a mesma falha em várias camadas. Na inicialização, a causa é
propagada ao contêiner, que registra a falha de deployment.

Não podem ser registrados:

- corpo XML, conteúdo ou nome de upload;
- número, cliente ou descrição do pedido;
- URL, usuário, senha, wallet ou endereço do Oracle;
- valores de configuração do ambiente.

O teste de runtime procura no `server.log` o identificador de correlação, o
evento aceito e
`legacy_validator_order=numero-formato,valor-monetario,status-inicial`.
A fixture `pedido-invalido-validador.xml` também deve produzir HTTP `400` e o
evento `legacy_xml_import rejected reason=domain_validator`, com a mesma
correlação da requisição e sem persistência parcial.

## Acoplamento transitivo observado

Reflections 0.9.10 declara `slf4j-api` 1.6.1 como dependência opcional. O WAR
não empacota SLF4J; no WildFly 9 a API é disponibilizada implicitamente pelo
subsistema de logging. Isso cria um acoplamento de classloader que precisa ser
revalidado em cada troca de servidor. A fase final remove Reflections e Log4j
1, sem adicionar outro backend concorrente ao WAR.
