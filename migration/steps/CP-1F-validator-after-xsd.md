# CP-1F — regra de negócio depois do XSD

## Situação observada

Os validadores `numero-formato` e `valor-monetario` repetiam restrições do
XSD. Como XMLBeans rejeita o documento antes da descoberta e execução dos
validadores, não existia uma fixture capaz de comprovar uma rejeição originada
no mecanismo descoberto por Reflections.

## Causa

Validação estrutural e regra de negócio tinham a mesma cobertura. O teste
confirmava a ordem das classes e uma importação aceita, mas não demonstrava
que uma implementação descoberta poderia impedir a persistência.

## Correção mínima

O XSD continua aceitando os três estados persistidos. O novo validador
`status-inicial`, de ordem 30, exige que uma importação crie somente pedidos em
`NOVO`. A exceção específica distingue essa falha das violações estruturais e
gera o log sanitizado `reason=domain_validator`.

A fixture `pedido-invalido-validador.xml` usa `APROVADO`. A validação estática
prova que ela atende ao XSD; os contratos H2 e Oracle exigem HTTP `400`, o
evento específico no log e ausência de `XML-VALIDATOR-0001` na listagem.

## Aplicação em um sistema real

Separe regras de formato das invariantes do processo. Para cada extensão
descoberta dinamicamente, mantenha ao menos um caso que chegue até ela e
observe seu efeito, não apenas um teste que confirme que a classe foi
encontrada.

## Rollback

Reverter o validador, sua exceção e a fixture retorna ao contrato anterior,
mas também remove a prova funcional de rejeição pelo Reflections.
