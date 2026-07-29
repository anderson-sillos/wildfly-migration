# Perfis de datasource do WildFly 26

Estes arquivos preservam os contratos dos perfis legados, mas usam o modelo de
gerenciamento do WildFly 26.1.3.Final.

A CLI do WildFly 9 aceitava `pool-name=MigrationDS` na operação
`data-source:add`. No WildFly 26, o nome do recurso
`data-source=MigrationDS` já identifica o pool e o parâmetro `pool-name` não é
mais suportado. Reaproveitar diretamente o arquivo antigo falha antes de criar
o datasource.

As diferenças ficam isoladas nestes arquivos. JNDI, URL H2, expressões Oracle,
tamanhos de pool, validação e transações permanecem equivalentes.
