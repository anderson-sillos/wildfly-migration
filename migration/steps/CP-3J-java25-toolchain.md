# INC-024 — política de compilação entre JDK 25 e release 21

## Identificação

- Checkpoint: `CP-3J`.
- Fonte: `javac` executado com JDK 25 usando `-source 21 -target 21`.
- Alvo: `maven.compiler.release=21` no perfil Jakarta do laboratório.
- Estágio: compilação.
- Categoria: política de toolchain.
- Reprodução: natural; a incompatibilidade aparece no build quando o compilador
  mais novo avalia a combinação de opções legada.

## Tentativa antes da correção

O build de qualificação do CP-3J foi executado pelo script
`scripts/build-cp-3j-java25.sh`, com o projeto configurado para produzir
bytecode Java 21. A configuração anterior separava `source` e `target`, o que
permitia ao JDK 25 emitir o aviso de compatibilidade relacionado aos módulos do
sistema. Com `-Werror`, esse aviso impedia a conclusão do build. A evidência
sanitizada está em `migration/evidence/CP-3J/java25-build-expected.properties`.

## Assinatura sanitizada

```text
warning: system modules path not set in conjunction with -source 21
error: warnings found and -Werror specified
```

Nenhum caminho local, usuário, segredo ou URL de banco faz parte do registro.

## Causa-raiz

`-source` e `-target` controlam partes diferentes da compilação e não expressam
sozinhos a plataforma Java usada para resolver APIs. Em um JDK 25, essa forma
legada gera o alerta sobre o caminho dos módulos e torna a política dependente
do compilador instalado.

## Menor correção

Usar a propriedade `maven.compiler.release` com valor `21` no perfil Jakarta.
O Maven passa uma única política de plataforma ao compilador, preservando o
bytecode e as APIs Java 21 sem exigir alteração funcional na aplicação.

## Evidências antes e depois

- Antes: `-source/-target 21` e o alerta convertido em falha pelo `-Werror`.
- Depois: `--release 21`, build Java 25 concluído e WAR validado pelo gate do
  CP-3J nos JDKs 21 e 25.

## Aplicação equivalente no sistema real

Centralizar a versão de plataforma no `maven-compiler-plugin` e remover
combinações independentes de `source` e `target`. A mudança é compatível com
builds reproduzíveis e não exige trocar o JDK de execução do WildFly.

## Teste de regressão

```text
./scripts/build-cp-3j-java25.sh
./scripts/validate-cp-3j-java25.sh
```

Os comandos devem terminar com sucesso e manter o relatório sem avisos de
compilação tratados como erro.

## Rollback

Restaurar a configuração aprovada no CP-3I, selecionar o commit registrado no
gate de rollback e repetir o build Java 21. O rollback não remove artefatos,
schemas ou dados externos.
