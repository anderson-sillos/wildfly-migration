# INC-NNN — título curto

## Identificação

- checkpoint:
- estado verde de origem:
- runtime de destino:
- etapa: `compilation`, `packaging`, `deployment`, `execution`, `startup`,
  `configuration` ou `verification`;
- categoria:
- reprodução: `natural` ou `fixture-opt-in`;
- perfis afetados: `portable-ci`, `oracle-qualified` ou ambos.

## Tentativa antes da correção

Registre o comando reproduzível, versões observadas, commit e checksum do WAR.
Não edite a aplicação antes desta tentativa.

## Assinatura sanitizada

Registre a menor assinatura estável que distingue a falha esperada. Não inclua
URL JDBC, host, serviço, usuário, credencial nem log bruto.

## Causa-raiz

Explique por que a mudança de runtime ou dependência expôs a incompatibilidade
e como ela foi isolada das demais mudanças do checkpoint.

## Menor correção

Descreva somente a alteração necessária para recuperar o contrato congelado.

## Evidências antes e depois

Relacione os arquivos legíveis por máquina. A falha esperada só conta como
cenário aprovado quando etapa, categoria e assinatura correspondem ao
catálogo. O resultado corrigido deve comparar contratos, persistência e WAR
com `migration/baselines/01-legacy/`.

## Aplicação equivalente no sistema real

Indique como localizar o mesmo risco, quais dados preservar e que decisão
operacional tomar na aplicação de produção.

## Teste de regressão

Liste os comandos que impedem o retorno da incompatibilidade.

## Rollback

Indique o último checkpoint verde e como voltar por novo commit, sem reescrever
o histórico nem executar limpeza destrutiva do banco.
