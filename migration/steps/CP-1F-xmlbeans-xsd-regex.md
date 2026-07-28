# CP-1F — expressão regular do XSD no XMLBeans 2.3.0

## Falha observada

O XSD havia sido aprovado pelo validador JAXP com o pattern:

```text
[A-Za-z0-9][A-Za-z0-9._-]*
```

Ao inicializar o endpoint no WildFly 9, o XMLBeans 2.3.0 recusou compilar o
schema porque interpretou o hífen como início de um intervalo inválido.

## Correção mínima

O hífen foi escapado dentro da classe de caracteres:

```text
[A-Za-z0-9][A-Za-z0-9._\-]*
```

A regra funcional permanece igual: o número começa com caractere alfanumérico
e os demais caracteres podem incluir ponto, sublinhado e hífen.

## Prova

O smoke deve implantar o WAR, inicializar o XMLBeans no primeiro acesso,
importar a fixture válida e rejeitar por HTTP `400` as fixtures inválida no
XSD, XXE e expansão de entidades. A mesma prova é executada em H2 e Oracle.

## Rollback

Reverter o commit desta tarefa restaura o XSD anterior e remove o endpoint. O
estado anterior continua seguro, mas não atende ao contrato de importação XML
do CP-1F.
