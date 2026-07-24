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
| Java 7 | Oracle JDK 7u80 | Download manual externo | Proprietário, obsoleto e não redistribuível pelo projeto |
| Java 8/17/21/25 | Eclipse Temurin/OpenJDK | Pacote ou arquivo oficial | OpenJDK, open source |
| Maven legado | 3.8.9 | Arquivo histórico oficial Apache | Open source e EOL; última versão disponível compatível com Java 7 |
| Maven moderno | 3.9.16 | Arquivo oficial Apache | Open source; requer JDK 8+ para executar |
| WildFly | 9.0.2, 26.1.3 e 41.0.0.Final | Arquivo da comunidade | WildFly comunitário open source |
| Oracle Database | 19c EE já disponível | Serviço externo | Proprietário; acesso e licença são responsabilidade do usuário |
| Drivers Oracle | `ojdbc7` legado e driver aprovado por gate | Fornecimento externo | Não versionar nem redistribuir |

Fontes oficiais:

- Git: <https://git-scm.com/book/en/v2/Getting-Started-Installing-Git>
- GitHub CLI: <https://github.com/cli/cli/blob/trunk/docs/install_linux.md>
- autenticação da GitHub CLI: <https://cli.github.com/manual/gh_auth_login>
- Docker Engine: <https://docs.docker.com/engine/install/>
- Eclipse Temurin: <https://adoptium.net/installation>
- licença OpenJDK: <https://openjdk.org/legal/>
- Oracle JDK 7u80: <https://www.oracle.com/java/technologies/javase/javase7-archive-downloads.html>
- Maven 3.9.16: <https://maven.apache.org/download.cgi>
- Maven 3.8.9: <https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/>
- WildFly comunitário: <https://www.wildfly.org/downloads/>
- Oracle Database 19c: <https://www.oracle.com/database/technologies/oracle-database-software-downloads.html>

Sempre releia os termos do fornecedor. O repositório registra proveniência e
checksums, mas não concede licença para redistribuir software proprietário.

## O que instalar em cada checkpoint

Não instale antecipadamente todos os runtimes. Cada checkpoint exige somente a
combinação abaixo; o `doctor` marca os componentes futuros como `NÃO EXIGIDO`.

| Quando | Componente obrigatório | Obtenção |
| --- | --- | --- |
| CP-1A e seguintes | Git 2.28+ e GitHub CLI | Pacotes oficiais da distribuição e do GitHub |
| CP-1B e seguintes | Docker Engine com Compose, ou runtime explicitamente suportado | Repositório oficial para o sistema operacional |
| CP-1B a CP-1F | Oracle JDK 7u80 Linux x64 | Download manual autenticado; arquivo `jdk-7u80-linux-x64.tar.gz` |
| CP-1B a CP-2B | Apache Maven 3.8.9 | Arquivo histórico oficial `apache-maven-3.8.9-bin.tar.gz` |
| CP-1B, CP-1F e CP-2A | WildFly 9.0.2.Final | Distribuição Full/Web `wildfly-9.0.2.Final.tar.gz` |
| CP-1C e seguintes enquanto legado | Driver `ojdbc7` aprovado | Fornecido externamente; não versionar |
| CP-1D e checkpoints com persistência | Acesso ao Oracle Database 19c existente | URL, usuário e senha ou wallet fornecidos pelo DBA |
| CP-2A e CP-2B | Eclipse Temurin/OpenJDK 8 | A versão exata será fixada ao iniciar o CP-2A |
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
| Temurin/OpenJDK 8, 17, 21 e 25 | <https://adoptium.net/temurin/releases/> |
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

### OpenJDK 8, 17, 21 e 25

Use uma distribuição baseada em OpenJDK, preferencialmente Eclipse Temurin, via
pacote ou arquivo oficial. A página de releases permite selecionar versão,
sistema, arquitetura e JDK; todos os arquivos oferecem checksum SHA-256.
Mantenha cada JDK em diretório próprio e configure `JAVA8_HOME`, `JAVA17_HOME`,
`JAVA21_HOME` e `JAVA25_HOME`, com seus arquivos e digests correspondentes.

O destino final será fixado em uma build OpenJDK 25 aprovada. Oracle JDK não
será aceito nesse gate.

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

O `doctor` executa essa instalação explicitamente com `JAVA7_HOME` e rejeita
outra versão do Maven ou da JVM.

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
legado. Configure:

```text
WILDFLY9_HOME=/opt/migration-lab/tools/wildfly-9.0.2.Final
WILDFLY26_HOME=/opt/migration-lab/tools/wildfly-26.1.3.Final
WILDFLY41_HOME=/opt/migration-lab/tools/wildfly-41.0.0.Final
```

Use somente WildFly comunitário. JBoss EAP não substitui o runtime definido pelo
laboratório. WildFly 9 e 26 devem permanecer em loopback ou rede interna; o
WildFly 41 expõe apenas as portas necessárias aos testes.

## 7. Oracle Database 19c

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

Exemplos futuros:

```bash
./scripts/doctor.sh CP-1B --env .env
./scripts/doctor.sh CP-2C --env .env
./scripts/doctor.sh CP-3J --env .env
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
