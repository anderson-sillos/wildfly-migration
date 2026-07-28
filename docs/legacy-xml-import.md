# Importação XML legada

O CP-1F expõe `POST /wildfly-migration/pedidos/importar-xml` para reproduzir
o processamento histórico com XMLBeans 2.3.0 e dom4j 1.6.1. O corpo deve usar
`Content-Type: application/xml` ou `text/xml` e não pode exceder 128 KiB.

Para uso manual, abra `GET /wildfly-migration/pedidos/importar-xml`, selecione
um arquivo `.xml` e envie o formulário. Essa página usa
`multipart/form-data`; o servidor aceita exatamente o campo `arquivoXml`,
limita o arquivo a 128 KiB, limita a requisição a 160 KiB e elimina o item
temporário depois da leitura.

## Ordem do processamento

1. o corpo é lido com limite explícito;
2. XMLBeans compila o XSD empacotado e valida o documento completo;
3. dom4j extrai número, cliente, descrição, valor e status;
4. os validadores descobertos por Reflections executam as regras de negócio;
5. somente depois dessas etapas o repositório abre a transação e insere o
   pedido.

Assim, XML malformado, incompatível com o XSD ou contendo `DOCTYPE` é
rejeitado antes da persistência. O leitor SAX bloqueia DTD externa, entidades
gerais e entidades de parâmetro; a resolução externa também falha de modo
fechado. O endpoint não registra o corpo XML.

## Respostas observáveis

- documento válido: redirecionamento para o detalhe, com
  `data-xml-import-status="ok"` e os valores importados;
- XML malformado, inseguro ou inválido no XSD: HTTP `400`, erro sanitizado e
  nenhuma inclusão parcial;
- XML válido no XSD, mas inválido em regra de negócio: HTTP `400`, log com
  `reason=domain_validator` e nenhuma inclusão parcial;
- tipo de mídia diferente de XML: HTTP `415`;
- corpo acima de 128 KiB: HTTP `413`;
- falha de persistência: HTTP `503`, sem endereço ou credencial do banco.

As fixtures portáveis ficam em `contract-tests/fixtures/xml/`.
`pedido-invalido-validador.xml` usa status `APROVADO`: ele é válido no XSD,
mas deve ser rejeitado porque todo pedido importado precisa iniciar em `NOVO`.
Os casos XXE e expansão de entidades são deliberadamente hostis e devem sempre
resultar em HTTP `400`.

O primeiro deploy também revelou que XMLBeans 2.3.0 rejeita um hífen não
escapado na classe de caracteres do `pattern`, embora o validador JAXP usado
na preparação da fixture o aceitasse. A falha reproduzida e a correção mínima
estão em
[`CP-1F-xmlbeans-xsd-regex.md`](../migration/steps/CP-1F-xmlbeans-xsd-regex.md).
O caso em que validadores redundantes ao XSD não podiam ser exercitados e sua
correção estão em
[`CP-1F-validator-after-xsd.md`](../migration/steps/CP-1F-validator-after-xsd.md).

## Validação automatizada

```bash
./scripts/validate-cp-1f-xml.sh
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/smoke-wildfly9-datasource.sh \
  --profile ci-h2 \
  --env .env \
  --war app/target/wildfly-migration.war
```

O mesmo smoke deve ser repetido com `--profile oracle`, sem reconstruir o WAR,
antes do encerramento do checkpoint.
