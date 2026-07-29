# Preparação do ambiente

Este guia prepara o host para todos os checkpoints, mas o `doctor` exige somente
o subconjunto necessário ao checkpoint selecionado. Execute o baseline legado
em máquina descartável, container ou VM isolada e sem bind em interface pública.

## Inventário e distribuição

| Componente | Versão/linha | Fornecimento | Classificação |
| --- | --- | --- | --- |
| Git | 2.28+ | Pacote do sistema | Open source |
| GitHub CLI (`gh`) | Versão suportada atual | Pacote oficial | Open source |
| Docker Engine/Compose ou equivalente | Versão estável suportada | Pacote oficial | Engine open source; confira os termos do produto escolhido |
| Java 7 histórico | Oracle JDK 7u80 | Download manual externo | Proprietário, EOL e não redistribuível pelo projeto |
| Java 7 portátil | Zulu 7.56.0.11 CA / OpenJDK 7u352 | Arquivo oficial Azul | OpenJDK, redistribuível, EOL e exclusivo de `portable-ci` |
| Java 8 | Eclipse Temurin OpenJDK 8u492-b09 | Arquivo oficial fixado no CP-2A | OpenJDK, open source |
| Java 17/21/25 | Eclipse Temurin/OpenJDK | Pacote ou arquivo oficial a fixar no gate correspondente | OpenJDK, open source |
| Maven legado | 3.8.9 | Arquivo histórico oficial Apache | Open source e EOL; última versão disponível compatível com Java 7 |
| Maven moderno | 3.9.16 | Arquivo oficial Apache | Open source; requer JDK 8+ para executar |
| WildFly | 9.0.2, 26.1.3 e 41.0.0.Final | Arquivo da comunidade | WildFly comunitário open source |
| Oracle Database | 19c EE já disponível | Serviço externo | Proprietário; acesso e licença são responsabilidade do usuário |
| Drivers Oracle | `ojdbc7` legado e driver aprovado por gate | Fornecimento externo | Não versionar nem redistribuir |
| Banco portátil | H2 1.4.200 | Maven Central; módulo de runtime | Open source, EOL e exclusivo de `portable-ci` |

Fontes oficiais:

- Git: <https://git-scm.com/book/en/v2/Getting-Started-Installing-Git>
- GitHub CLI: <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>
- autenticação da GitHub CLI: <https://cli.github.com/manual/gh_auth_login>
- Docker Engine: <https://docs.docker.com/engine/install/>
- Eclipse Temurin: <https://adoptium.net/installation>
- Temurin 8u492-b09 Linux x64:
  <https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz>
- licença OpenJDK: <https://openjdk.org/legal/>
- Oracle JDK 7u80: <https://www.oracle.com/java/technologies/javase/javase7-archive-downloads.html>
- Azul Metadata API: <https://api.azul.com/metadata/v1/zulu/packages/f436b3cb-0115-4814-b7fa-e180747bd68f>
- termos do Azul Zulu: <https://www.azul.com/products/core/openjdk-terms-of-use/>
- Maven 3.9.16: <https://maven.apache.org/download.cgi>
- Maven 3.8.9: <https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/>
- WildFly comunitário: <https://www.wildfly.org/downloads/>
- Oracle Database 19c: <https://www.oracle.com/database/technologies/oracle-database-software-downloads.html>
- H2 1.4.200: <https://github.com/h2database/h2database/releases/tag/version-1.4.200>
- licença H2: <https://h2database.com/html/license.html>

Sempre releia os termos do fornecedor. O repositório registra proveniência e
checksums, mas não concede licença para redistribuir software proprietário.

## O que instalar em cada checkpoint

Não instale antecipadamente todos os runtimes. Cada checkpoint exige somente a
combinação abaixo; o `doctor` marca os componentes futuros como `NÃO EXIGIDO`.

| Quando | Componente obrigatório | Obtenção |
| --- | --- | --- |
| CP-1A e seguintes | Git 2.28+ e GitHub CLI | Pacotes oficiais da distribuição e do GitHub |
| CP-1B e seguintes | Docker Engine com Compose, ou runtime explicitamente suportado | Repositório oficial para o sistema operacional |
| CP-1B e CP-1C; perfil `oracle` a partir do CP-1D | Oracle JDK 7u80 Linux x64 | Reprodução exata; download manual autenticado; arquivo `jdk-7u80-linux-x64.tar.gz` |
| Perfil `ci-h2` a partir do CP-1D | Zulu 7.56.0.11 CA / OpenJDK 7u352 | Trilha portátil; arquivo `zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz` |
| CP-1B a CP-2B | Apache Maven 3.8.9 | Arquivo histórico oficial `apache-maven-3.8.9-bin.tar.gz` |
| CP-1B a CP-1G e CP-2A | WildFly 9.0.2.Final | Distribuição Full/Web `wildfly-9.0.2.Final.tar.gz` |
| CP-1C a CP-1G no Oracle JDK | Truststore JKS atualizado | Pacote de certificados do sistema; não substituir por conexão insegura |
| Perfil `ci-h2` a partir do CP-1D | H2 1.4.200 | JAR oficial como módulo do WildFly, nunca como dependência do WAR |
| CP-1D e seguintes enquanto legado | Driver `ojdbc7` aprovado | Fornecido externamente; não versionar |
| CP-1D e checkpoints com persistência | Acesso ao Oracle Database 19c existente | URL, usuário e senha ou wallet fornecidos pelo DBA |
| CP-2A e CP-2B | Eclipse Temurin OpenJDK 8u492-b09 | `OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz`, URL e digest fixados no manifesto |
| CP-2B a CP-3D | WildFly 26.1.3.Final | Distribuição EE 8 `wildfly-26.1.3.Final.tar.gz` |
| CP-2C e seguintes | Apache Maven 3.9.16 | Distribuição binária oficial |
| CP-3A a CP-3D | Eclipse Temurin/OpenJDK 17 | A build exata será fixada no CP-3A |
| CP-3E a CP-3I | Eclipse Temurin/OpenJDK 21 e WildFly 41.0.0.Final | Builds exatas fixadas no CP-3E |
| CP-3H e seguintes | `com.oracle.database.jdbc:ojdbc17:23.26.2.0.0` | Provisionado no WildFly, fora do WAR |
| CP-3J e CP-3K | Eclipse Temurin/OpenJDK 25 e WildFly 41.0.0.Final | Destino final exclusivamente open source |

Para o checkpoint atual, siga a
[lista de downloads do runtime legado](../runtime/legacy/README.md). Os links
das fases futuras estão documentados abaixo apenas para planejamento; não use
uma referência flutuante como `latest`. Cada arquivo será fixado por versão e
checksum quando entrar no respectivo checkpoint.

### Endereços das fases futuras

| Componente | Fonte oficial |
| --- | --- |
| Temurin/OpenJDK 17, 21 e 25 | <https://adoptium.net/temurin/releases/> |
| WildFly 26.1.3.Final EE 8 | <https://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.tar.gz> |
| Maven 3.9.16 | <https://maven.apache.org/download.cgi> |
| WildFly 41.0.0.Final | <https://github.com/wildfly/wildfly/releases/download/41.0.0.Final/wildfly-41.0.0.Final.tar.gz> |
| Oracle JDBC | <https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html> |

## 1. Git e GitHub

Instale Git pelo gerenciador de pacotes do sistema. No Ubuntu/Debian:

```bash
sudo apt update
sudo apt install git
git --version
```

Instale `gh` seguindo o repositório de pacotes oficial indicado acima. Depois,
configure a identidade do autor:

```bash
git config --global user.name "Seu Nome"
git config --global user.email "email-verificado-no-github@example.com"
```

Para limitar a automação ao resource owner `anderson-sillos`, prefira um
fine-grained personal access token com expiração curta. Durante o bootstrap, em
que o repositório já existe, selecione somente `wildfly-migration` e conceda:

- `Administration: read and write`;
- `Contents: read and write`;
- `Workflows: read and write`;
- `Pull requests: read and write`.

Se a política do resource owner exigir aprovação, aguarde a aprovação antes de
prosseguir. Carregue o token apenas na sessão atual, sem digitá-lo em comandos ou
salvá-lo no projeto:

```bash
read -rsp "Token GitHub: " GH_TOKEN
export GH_TOKEN
gh api user --jq .login
```

Ao terminar:

```bash
unset GH_TOKEN
```

Nunca grave tokens em `.env`, URLs de remote, comandos versionados ou
documentação. Se optar pelo OAuth interativo da GitHub CLI, considere que ele não
oferece o mesmo isolamento por resource owner/repositório.

## 2. Runtime de containers

Instale Docker Engine e o plugin Compose pelo procedimento oficial da sua
distribuição. Verifique:

```bash
docker version
docker compose version
docker info
```

`docker version` pode mostrar apenas o cliente quando o daemon está parado;
`docker info` precisa concluir com sucesso. Podman pode ser usado futuramente se
os scripts do checkpoint declararem suporte explícito.

## 3. Diretório externo de ferramentas

Não extraia runtimes dentro do checkout. Use, por exemplo:

```bash
sudo install -d -m 0755 /opt/migration-lab
sudo install -d -m 0755 /opt/migration-lab/archives
sudo install -d -m 0755 /opt/migration-lab/tools
```

Se o host não permitir `/opt`, escolha outro diretório fora do repositório e
ajuste os caminhos no seu `.env`.

Para todo arquivo baixado, valide o digest aprovado antes de extrair:

```bash
sha256sum /caminho/para/arquivo
```

No runtime legado, o valor aprovado é fixado em
`runtime/legacy/runtime-manifest.tsv`; a variável `*_ARCHIVE_SHA256` pode
repeti-lo, mas não substituí-lo. O `doctor` compara o arquivo externo ao
manifesto sem copiá-lo.

## 4. Java

### Java 7u80

O Oracle JDK 7u80 exige conta Oracle, usa licença proprietária, está sem
correções atuais e não é recomendado para produção. Baixe-o manualmente do
arquivo oficial, valide o checksum aprovado pelo responsável pelo laboratório,
extraia fora do checkout e configure:

```text
JAVA7_HOME=/opt/migration-lab/tools/jdk1.7.0_80
JAVA7_ARCHIVE=/opt/migration-lab/archives/jdk-7u80-linux-x64.tar.gz
JAVA7_ARCHIVE_SHA256=bad9a731639655118740bee119139c1ed019737ec802a630dd7ad7aab4309623
JAVA7_TRUSTSTORE=/etc/ssl/certs/java/cacerts
```

Ele será usado somente para executar o baseline isolado. A Oracle não publica o
digest na página de arquivo; o projeto fixou o checksum calculado sobre o
arquivo licenciado fornecido pelo responsável. Consulte o
[procedimento do runtime legado](../runtime/legacy/README.md).

Na página da Oracle, localize **Java SE Development Kit 7u80**, escolha
**Linux x64 — 146.42 MB** e baixe o JDK, não o JRE nem o Server JRE. A origem
direta exibida pela própria página é:

```text
https://download.oracle.com/otn/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz
```

Esse endereço exige aceite da licença e login Oracle. Faça a autenticação no
navegador e nunca compartilhe login, senha, cookie ou URL temporária de sessão
com o projeto.

#### HTTPS atual a partir do Java 7

O primeiro build do CP-1C reproduziu dois problemas distintos: o protocolo TLS
1.2 não era selecionado e, depois de habilitá-lo, o truststore de 2015 falhou
com `PKIX path building failed`. Não desabilite a validação HTTPS.

No Ubuntu/Debian, instale ou atualize o pacote de certificados Java e confirme
que o próprio Java 7 consegue ler o JKS:

```bash
sudo apt update
sudo apt install ca-certificates-java
/opt/migration-lab/tools/jdk1.7.0_80/bin/keytool \
  -list \
  -keystore /etc/ssl/certs/java/cacerts \
  -storepass changeit
```

Configure `JAVA7_TRUSTSTORE` com esse caminho. Em outra distribuição, informe
um truststore JKS atualizado e confiável, fornecido pelo sistema operacional.
O wrapper habilita TLS 1.2 e aponta somente o processo Maven para esse arquivo;
ele não modifica o JDK proprietário. A tentativa, os erros exatos, a correção e
o rollback estão em
[`CP-1C-legacy-build-https.md`](../migration/steps/CP-1C-legacy-build-https.md).

### Zulu OpenJDK 7 para `portable-ci`

O CI não redistribui nem executa o Oracle JDK. O perfil `ci-h2` usa exatamente
Zulu `7.56.0.11-ca`, OpenJDK `1.7.0_352-b01`, Linux x64:

```text
https://cdn.azul.com/zulu/bin/zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz
SHA-256: 8a7387c1ed151474301b6553c6046f865dc6c1e1890bcf106acc2780c55727c8
```

Essa é uma distribuição Community Availability open source, sob GPLv2 com
Classpath Exception. A linha Java 7 e essa build gratuita estão EOL; use-as
somente no runner efêmero do laboratório. A aprovação com OpenJDK 7u352 não
substitui a reprodução histórica em Oracle JDK 7u80.

A decisão, a comparação das candidatas e os smokes executados estão em
[seleção do runtime portátil](cp-1d-runtime-selection.md). O manifesto
específico é
[`portable-runtime-manifest.tsv`](../runtime/legacy/portable-runtime-manifest.tsv).

### OpenJDK 8, 17, 21 e 25

O CP-2A fixa Eclipse Temurin OpenJDK `8u492-b09`. Baixe exatamente
`OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz` da
[URL versionada oficial](https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz)
e valide SHA-256
`da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e`.
O [manifesto do CP-2A](../runtime/phase2/java8-wildfly9/runtime-manifest.tsv)
registra origem e licença.

Para Java 17, 21 e 25, use uma distribuição baseada em OpenJDK,
preferencialmente Eclipse Temurin, mas fixe a build somente no gate
correspondente. Mantenha cada JDK em diretório próprio e configure seus arquivos
e digests correspondentes.

O destino final será fixado em uma build OpenJDK 25 aprovada. Oracle JDK não
será aceito nesse gate.

### VS Code no baseline Java 7

Na tag do baseline, o build Maven continua sendo a fonte de verdade. Para que o
diagnóstico do editor também aceite `source` e `target` 1.7, use a extensão
Language Support for Java by Red Hat exatamente na versão `1.32.0`. A partir da
versão `1.33.0`, a plataforma do servidor de linguagem deixou de compilar
projetos anteriores ao Java 8; atualizar a extensão durante a fase 1 faz o
editor exibir a mensagem `Minimal supported version is '1.8'`, embora o build
real com Java 7 continue válido.

Em uma janela VS Code conectada ao mesmo ambiente remoto do projeto, instale e
confirme a versão:

```bash
code --install-extension redhat.java@1.32.0 --force
code --list-extensions --show-versions | grep '^redhat\.java@'
```

O resultado esperado na reprodução da tag é `redhat.java@1.32.0`. No CP-2A, o
código já usa Java 8 e a restrição histórica da extensão deixa de ser
necessária. O workspace relaciona `JavaSE-1.7` ao Zulu 7 portátil e define
`JavaSE-1.8` no Temurin 8u492 como padrão em `.vscode/settings.json`; adapte
apenas os caminhos locais se o host usar diretórios diferentes.

Depois da troca de versão, abra a paleta de comandos e execute, nesta ordem:

1. `Developer: Reload Window`;
2. `Java: Clean Java Language Server Workspace`;
3. confirme o reinício e a remoção do cache solicitados pelo comando.

Para validar todos os arquivos de uma vez, pressione `Ctrl+Shift+B` e execute a
tarefa padrão `CP-2A: validar Java 8 em massa`. Ela chama o build completo
com o perfil `ci-h2`, Java 8 e Maven 3.8.9. Os comandos `Java: Force Java
Compilation` ou `Java Projects: Rebuild All` podem atualizar os marcadores do
editor, mas não substituem este build:

```bash
./scripts/doctor.sh CP-2A --profile ci-h2 --env .env
./scripts/build-cp-2a.sh --profile ci-h2 --env .env
```

Referências: [histórico de versões do VS Code Java][vscode-java-changelog] e
[matriz de compilação do Eclipse JDT Language Server][jdtls-readme].

[vscode-java-changelog]: https://github.com/redhat-developer/vscode-java/blob/main/CHANGELOG.md
[jdtls-readme]: https://github.com/eclipse-jdtls/eclipse.jdt.ls

## 5. Maven

### Maven 3.8.9 no legado

Maven 3.8.9 é a última versão disponível capaz de executar com Java 7. Ela está
em fim de vida e será usada somente do CP-1B ao CP-2B. Baixe o arquivo e o
SHA-512 no arquivo histórico oficial da Apache, valide-os e extraia fora do
checkout. Configure:

```text
https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/apache-maven-3.8.9-bin.tar.gz
https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/apache-maven-3.8.9-bin.tar.gz.sha512
```

```text
MAVEN_HOME=/opt/migration-lab/tools/apache-maven-3.8.9
MAVEN_ARCHIVE=/opt/migration-lab/archives/apache-maven-3.8.9-bin.tar.gz
MAVEN_ARCHIVE_SHA256=3e4c68cdd70f96635e713f36c8fc3ea3182035245d3da2156576710ca0fe4b0c
```

Até a tag da fase 1, o `doctor` executa essa instalação com Java 7. No CP-2A e
CP-2B, o mesmo Maven 3.8.9 executa com o Temurin Java 8 fixado.

Para construir e auditar o WAR do CP-1C:

```bash
./scripts/doctor.sh CP-1C --env .env
./scripts/validate-cp-1c.sh
./scripts/build-cp-1c.sh --env .env
```

O último comando gera `app/target/wildfly-migration.war`, registra a árvore de
dependências em `app/target/dependency-tree.txt` e rejeita divergências de
`WEB-INF/lib`, APIs do contêiner, `ojdbc7`, JARs manuais ou bytecode diferente
de Java 7.

### Maven 3.9.16 a partir do CP-2C

Maven 3.9.16 é a versão GA aprovada pelo plano. Ele requer JDK 8 ou superior para
executar e se torna obrigatório no CP-2C, depois da saída do Java 7. Baixe o
arquivo binário e o `.sha512` oficiais, valide-os e extraia externamente:

```bash
sha512sum -c apache-maven-3.9.16-bin.tar.gz.sha512
```

Configure `MAVEN_HOME` e confirme:

```bash
/opt/migration-lab/tools/apache-maven-3.9.16/bin/mvn --version
```

O número `4.0.0` em `<modelVersion>` de um `pom.xml` é o modelo do POM e não
significa que Maven 4 esteja sendo usado.

## 6. WildFly comunitário

Baixe as distribuições 9.0.2, 26.1.3 e 41.0.0.Final da página oficial, valide o
digest aprovado e extraia cada uma fora do checkout. Para o WildFly 9, use
exatamente o arquivo `wildfly-9.0.2.Final.tar.gz` e o digest fixado no manifesto
legado. Para o CP-2B, use o arquivo comunitário
`wildfly-26.1.3.Final.tar.gz`, publicado em
<https://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.tar.gz>.
O release oficial publicou SHA-1
`b9f52ba41df890e09bb141d72947d2510caf758c`; o laboratório fixa também o
SHA-256
`aadd317c62616f6b5735ae92151d06c1f03c46eba448958d982c61f02528ae59`.
Configure:

```text
WILDFLY9_HOME=/opt/migration-lab/tools/wildfly-9.0.2.Final
WILDFLY26_HOME=/opt/migration-lab/tools/wildfly-26.1.3.Final
WILDFLY41_HOME=/opt/migration-lab/tools/wildfly-41.0.0.Final
```

Use somente WildFly comunitário. JBoss EAP não substitui o runtime definido pelo
laboratório. WildFly 9 e 26 devem permanecer em loopback ou rede interna; o
WildFly 41 expõe apenas as portas necessárias aos testes.

## 7. Oracle Database 19c

Antes do perfil Oracle, o CP-1D usa H2 1.4.200 em memória somente para feedback
portátil. O H2 será provisionado como módulo do WildFly, não abrirá console ou
listener de rede e não poderá aparecer em `WEB-INF/lib`:

```text
https://repo.maven.apache.org/maven2/com/h2database/h2/1.4.200/h2-1.4.200.jar
SHA-256: 3ad9ac4b6aae9cd9d3ac1c447465e1ed06019b851b893dd6a8d76ddb6d85bca6
```

H2 1.4.200 está EOL e sua compatibilidade Oracle é parcial. O resultado é
sempre `portable-ci`; somente a execução abaixo no Oracle 19c pode produzir
`oracle-qualified`.

O laboratório usa o Oracle Database 19c EE existente. Não cria nem publica uma
imagem do banco. Solicite ao DBA:

- URL JDBC ou alias/wallet;
- usuário com o menor conjunto de privilégios;
- senha por canal seguro;
- Release Update efetivamente instalado;
- política para schema de laboratório, limpeza e limites de conexão.

Copie `.env.example` para `.env` e preencha apenas localmente:

```text
ORACLE_DB_URL=
ORACLE_DB_USER=
ORACLE_DB_PASSWORD=
ORACLE_DB_WALLET=
```

O `doctor` informa somente se cada valor está presente.

## 8. Diagnóstico por checkpoint

```bash
cp .env.example .env
./scripts/doctor.sh CP-1A --env .env
```

A partir do CP-1D, selecione explicitamente uma das duas trilhas:

| Perfil | Exige | Não exige | Resultado possível |
| --- | --- | --- | --- |
| `ci-h2` | Zulu Java 7 portátil, Maven 3.8.9, WildFly 9 e H2 fixados | Oracle JDK, truststore externo, `ojdbc7` e qualquer segredo Oracle | `portable-ci` |
| `oracle` | Oracle JDK 7u80, truststore, Maven 3.8.9, WildFly 9, `ojdbc7`, URL, usuário e senha | Zulu Java 7 e H2 | `oracle-qualified`, depois da suíte interna |

No CP-2A, os dois perfis passam a exigir o mesmo Temurin Java 8u492 e WildFly
9. O perfil `ci-h2` acrescenta H2; o perfil `oracle` acrescenta `ojdbc7` e a
configuração externa do Oracle 19c.

O perfil não é armazenado no `.env`. A partir do `CP-1D`, todo comando
aplicável exige `--profile ci-h2` ou `--profile oracle` explicitamente.
O modo `--ci` é não interativo e recusa o perfil `oracle`, impedindo que o
workflow hospedado dependa de rota ou credenciais internas.

```bash
./scripts/doctor.sh CP-1E --profile ci-h2 --env .env
./scripts/doctor.sh CP-1E --profile oracle --env .env
./scripts/doctor.sh CP-2A --profile ci-h2 --env .env
./scripts/doctor.sh CP-2A --profile oracle --env .env
```

Build, preparação do schema, inicialização, URLs, testes manuais, stop e
limpeza estão consolidados no
[runbook da aplicação legada](legacy-application-runbook.md). Esta página
permanece como fonte para instalação, versões e variáveis.
Para o estado atual, use o
[runbook do CP-2A](cp-2a-java8-wildfly9.md).

O GitHub Actions executa somente a trilha `ci-h2`. A execução Oracle deve
ocorrer em um host autorizado na rede interna e com
`OJDBC7_JAR`, `OJDBC7_SHA256`, `ORACLE_DB_URL`, `ORACLE_DB_USER` e
`ORACLE_DB_PASSWORD` definidos no `.env` ignorado. Não copie esses valores para
o workflow, para logs ou para o repositório.

O perfil `ci-h2` não valida nem exige `ORACLE_DB_*` ou `OJDBC7_*`. O perfil
`oracle` não valida nem exige `JAVA7_PORTABLE_*` ou `H2_*`. Senhas e URLs nunca
são impressas; o diagnóstico informa somente presença, validade estrutural e
resultado da conectividade quando esse teste estiver disponível.

Outros exemplos:

```bash
./scripts/doctor.sh CP-1B --env .env
./scripts/doctor.sh CP-2C --profile ci-h2 --env .env
./scripts/doctor.sh CP-3J --profile ci-h2 --env .env
```

Um resultado `NÃO EXIGIDO` significa que o checkpoint ainda não depende daquele
componente; não equivale a uma validação positiva.

## 9. Reprodução do CP-1A

Depois que o repositório remoto existir:

```bash
git clone https://github.com/anderson-sillos/wildfly-migration.git
cd wildfly-migration
bash -n scripts/doctor.sh
./scripts/doctor.sh CP-1A
```

Resultado esperado: nenhum `FALHA`, identidade Git configurada, `gh`
autenticado, `origin` presente e arquivos sensíveis ignorados.
