# Catálogo de incompatibilidades

O arquivo [`incompatibilities.tsv`](incompatibilities.tsv) é o índice
versionado dos riscos observados durante as três fases. Cada linha relaciona a
versão de origem, o runtime alvo, a etapa em que o problema aparece, a
categoria, a forma de reprodução, o estado e o registro detalhado.

As etapas são `compilation`, `packaging`, `deployment`, `startup`,
`configuration`, `execution` ou `verification`. A reprodução é:

- `natural`: a tentativa do checkpoint anterior no runtime seguinte produziu
  a assinatura sem alterar código ou configuração antes da captura;
- `fixture-opt-in`: a reprodução natural não é segura ou determinística, então
  um arquivo isolado é executado somente quando explicitamente solicitado.

Fixtures não são executadas por padrão no fluxo funcional. O índice
[`incompatibility-fixtures.tsv`](incompatibility-fixtures.tsv) exige que cada
fixture seja opt-in (`enabled_by_default=false`), exista no checkout e aponte
para o mesmo registro do catálogo. Atualmente elas cobrem a rejeição de uma
regra de domínio após o XSD e a rejeição de XXE; nenhum teste abre rede ou
persiste dados permanentes.

## Validação

O validador confirma o cabeçalho, IDs únicos, referências, valores permitidos,
fixtures existentes, cobertura mínima e ausência de segredos:

```bash
./scripts/validate-incompatibility-catalog.sh
```

A cobertura mínima inclui Java/toolchain, namespaces Jakarta, APIs indevidas no
WAR, Tiles/TLD, upload, logging, MyBatis, reflexão e descoberta por annotation,
substituição do Reflections, Oracle JDBC, XMLBeans, APIs XML duplicadas e
dom4j. Cada registro detalhado segue
[`incompatibility-template.md`](incompatibility-template.md), mantendo a
assinatura sanitizada, evidência antes/depois, regressão e rollback.
