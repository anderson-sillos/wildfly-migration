# Evidência CP-1G — Baseline legado completo

## Escopo

- branch: `checkpoint/cp-1g-complete-legacy-baseline`;
- estado verde anterior: squash `8ca6b1b`, fechamento do `CP-1F`;
- runtime oficial: Oracle JDK 7u80, Maven 3.8.9, WildFly 9.0.2.Final,
  `ojdbc7` 12.1.0.2.0 e Oracle Database 19c RU 19.3;
- runtime portátil: Zulu OpenJDK 7u352, Maven 3.8.9, WildFly 9.0.2.Final e
  H2 1.4.200 em memória;
- bind HTTP e management restrito a loopback;
- nenhum binário, segredo, URL JDBC, identidade do schema ou log bruto é
  versionado nesta evidência.

## Baseline congelado

`migration/baselines/01-legacy/` registra:

- 14 resultados normalizados do contrato HTTP externo;
- estado Oracle de referência, objetos `LAB_*`, seed `LAB-0001` e efeitos
  persistidos esperados;
- matriz H2/Oracle separada, sem promover H2 a qualificação oficial;
- sete componentes de runtime, build, banco e drivers com versão, origem,
  licença e checksum quando aplicável;
- 24 dependências Maven diretas e transitivas com SHA-256 individual, das
  quais quatro são `provided` e 20 integram `WEB-INF/lib`;
- WAR SHA-256
  `9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`;
- árvore Maven SHA-256
  `2bd0439fb193fe3ba416980c3f3de606ae9152ca14a55b5dc5e01c018f9adcd6`.

O catálogo `migration/incompatibilities.tsv` e seu template estabelecem desde
este checkpoint o vínculo entre tentativa natural, assinatura sanitizada,
causa, correção mínima, evidência antes/depois, regressão e rollback.

## Validação estática e de empacotamento

Executada na branch do checkpoint:

```bash
./scripts/validate-cp-1g-baseline.sh
./scripts/build-cp-1d.sh --profile ci-h2 --env .env
./scripts/validate-cp-1g-baseline.sh \
  --war app/target/wildfly-migration.war
./scripts/validate-documentation.sh
```

Resultado: 14 cenários, 24 dependências, 20 JARs e os dois checksums congelados
foram reconciliados sem divergência.

## Resultados de runtime

Revisão qualificada:
`ea94065e682193b5581abbb003c2ca0b05d3f188`.

As duas trilhas executaram o mesmo WAR:

| Trilha | JVM e banco | Resultado |
| --- | --- | --- |
| `portable-ci` | Zulu OpenJDK 7u352 e H2 1.4.200 | 14/14 cenários aprovados |
| `oracle-qualified` | Oracle JDK 7u80, `ojdbc7` 12.1.0.2.0 e Oracle 19c RU 19.3 | 14/14 cenários aprovados |

Os relatórios sanitizados locais registraram o mesmo commit, runtime
`java7-wildfly9.0.2` e WAR SHA-256
`9dc324fcdb800e5f65ca7f54d42c65fb2ac6edcdda7ebddc023665fb6191edbe`.
Eles permanecem derivados ignorados em `app/target/`, sem endpoint ou
credencial.

O diagnóstico aprovou:

- H2: 98 verificações, nenhuma falha ou aviso;
- Oracle: 97 verificações, nenhuma falha ou aviso;
- bind em loopback e portas locais `18080`/`19990`;
- checksums de Java, Maven, WildFly, H2 e `ojdbc7`;
- ausência de segredo versionado ou empacotado.

O probe H2 executou schema e limpeza idempotentes duas vezes. O probe MyBatis
executou mappers, aliases, handler e transações. No Oracle, o `verify` confirmou
depois do smoke o produto 19c, RU `19.3.0.0.0`, objetos permitidos e todos os
valores canônicos do seed. A limpeza automática removeu somente
`LAB-SMOKE-*`.

### Correção na captura do RU

A primeira verificação exigiu o RU dentro de
`DatabaseMetaData.getDatabaseProductVersion()` e produziu um falso negativo.
A correção preservou a identificação do produto pela metadata JDBC e passou a
obter o RU exato por `PRODUCT_COMPONENT_VERSION.VERSION_FULL`. A tentativa,
causa e regressão estão em
`migration/steps/CP-1G-oracle-ru-detection.md` (`INC-004`).

### Checkout limpo

O commit qualificado foi materializado em worktree detached sob `/tmp`. Usando
somente a documentação e a configuração externa:

- `doctor CP-1G/ci-h2`: 98 verificações aprovadas;
- build Maven/Java 7: aprovado;
- WAR, árvore Maven e manifesto: idênticos ao congelado;
- WildFly 9/H2 e 14 contratos: aprovados;
- `git status --short`: vazio; somente `app/target/` ignorado foi produzido.

O isolamento inicial do executor ocultou a autenticação da GitHub CLI e o
socket Docker no novo diretório. O mesmo `doctor` foi repetido com acesso ao
host e aprovado, sem mudar configuração nem usar `--ci`. O worktree temporário
foi removido ao final.

O pull request
[`#14`](https://github.com/anderson-sillos/wildfly-migration/pull/14)
executou o workflow
[`30416762018`](https://github.com/anderson-sillos/wildfly-migration/actions/runs/30416762018)
sobre a revisão `5316b62` em um runner hospedado diferente do host local:

- `repository-baseline`: aprovado em 14 segundos;
- `portable-ci`: aprovado em 1 minuto e 40 segundos;
- download e checksums do runtime portátil: aprovados;
- build e WAR SHA-256 congelado: aprovados;
- checksums individuais dos 20 JARs extraídos de `WEB-INF/lib`: aprovados;
- probe MyBatis, lifecycle H2, WildFly 9 e 14 contratos: aprovados;
- relatório sanitizado publicado como artefato do workflow.

Essa execução comprova a reprodutibilidade do WAR em outra máquina. Uma
divergência futura deve falhar no gate e ser diagnosticada por artefato; os
checksums não devem ser atualizados apenas para aceitar o resultado.

## Reprodução e rollback

O procedimento completo está em
`docs/legacy-baseline-reproduction.md`: preparação externa, checkout limpo,
H2, Oracle, verificação, limpeza e rollback.

Até a criação da tag, o retorno deve ser feito por novo PR que reverta o futuro
squash do `CP-1G` e restaure `8ca6b1b`. Depois da publicação,
`migration/01-legacy-baseline` é imutável. Nenhum rollback Git executa
`rollback.sql`, remove o schema Oracle ou apaga a conta.

## Limitações conhecidas

- H2 continua sendo somente `portable-ci`;
- Oracle exige rede interna e componentes proprietários externos;
- o inventário de patches Oracle `one-off` não foi fornecido;
- todo o runtime e as bibliotecas da fase 1 são históricos e vários estão EOL
  ou possuem vulnerabilidades conhecidas, portanto permanecem isolados.
