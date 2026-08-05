# Reprodução do destino final CP-3K

## Escopo

Este procedimento parte de um checkout Git limpo, usa os runtimes externos
fixados no CP-3J e recompila a aplicação com Eclipse Temurin OpenJDK 25.0.4+7,
Maven 3.9.16 e WildFly Community 41.0.0.Final. H2 2.4.240 é executado como
portable-ci; somente a execução explícita no Oracle Database 19c RU 19.3
recebe oracle-qualified.

O executor cria um clone local temporário, portanto app/target, caches, logs,
drivers e .env do checkout de origem não são reutilizados. A configuração
externa é lida sem ser copiada para o clone ou para a evidência.

## 1. Preparar os componentes

Siga environment-setup.md, valide os SHA-256 dos manifestos Java 25/WildFly 41
e confirme que o arquivo externo contém JAVA25_HOME, JAVA25_ARCHIVE,
WILDFLY41_HOME, WILDFLY41_ARCHIVE, MAVEN_HOME e H2_JAR. Para Oracle, forneça
também OJDBC17_JAR, URL, usuário, senha e wallet conforme o ambiente
autorizado.

O arquivo deve ficar fora do Git e ter permissão restrita:

    install -m 0600 .env.example /caminho/seguro/wildfly-migration-cp3k.env

Não informe credenciais Oracle no perfil H2. Se o Java 25 ainda não estiver
instalado, interrompa a reprodução e instale o arquivo Temurin indicado no
manifesto antes de prosseguir.

## 2. Reprodução portátil

    ./scripts/reproduce-cp-3k.sh \
      --profile ci-h2 \
      --env /caminho/seguro/wildfly-migration-cp3k.env

O executor verifica o checkout de origem, cria um clone limpo, executa
doctor CP-3K --profile ci-h2 --non-interactive, valida a baseline, recompila
o WAR com --release 21 no JDK 25 e inicia o WildFly somente em loopback.
Depois aplica o datasource H2, executa os 15 contratos, a sonda de logging e a
auditoria de empacotamento.

A evidência sanitizada fica em
migration/evidence/CP-3K/reproduction-ci-h2.json por padrão. O resultado deve
registrar portable-ci, cleanCheckoutBefore=passed,
cleanCheckoutAfter=passed-source-tree, 15 cenários e oracleQualified como
not-executed.

## 3. Reprodução qualificada no Oracle

Somente em uma máquina autorizada na rede interna:

    ./scripts/reproduce-cp-3k.sh \
      --profile oracle \
      --env /caminho/seguro/wildfly-migration-cp3k.env

O executor sempre passa primeiro pelo H2. Em seguida instala o ojdbc17 no
módulo temporário, conecta ao datasource Oracle 19c, executa os mesmos 15
contratos e limpa apenas os registros transitórios da própria sonda. O
relatório deve registrar portable-ci e oracle-qualified como aprovados.
Se o Oracle não estiver acessível, preserve somente o resultado H2 e mantenha
oracleQualified=not-executed; isso não é uma aprovação parcial do banco.

## 4. Validação e limpeza

    ./scripts/validate-cp-3k-reproduction.sh \
      --profile ci-h2

Para uma evidência Oracle, use --profile oracle. O validador verifica o schema
do relatório, commit-fonte, checksum do WAR, 15 cenários, classificação dos
perfis, ausência de segredos/bind público e os comandos de reprodução. O clone
e o WildFly temporários são removidos ao final; nenhum DROP USER, DROP SCHEMA
ou alteração destrutiva de dados faz parte do rollback.

## 5. Falhas e rollback

- Checkout sujo: crie outro clone; não descarte alterações desconhecidas.
- Runtime ou checksum ausente: interrompa antes do build e corrija a instalação.
- Falha H2: não execute Oracle até a trilha portátil passar.
- Falha Oracle: classifique o checkpoint como não qualificado e preserve só
  evidência sanitizada.
- Rollback: abandone o clone temporário e retorne ao último checkpoint verde;
  não altere tags, schema ou usuário Oracle.
