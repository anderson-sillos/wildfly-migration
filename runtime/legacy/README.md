# Runtime legado isolado

O baseline histórico combina Oracle JDK 7u80, Apache Maven 3.8.9 e WildFly
9.0.2.Final. As versões, origens, licenças e os digests dessa reprodução ficam
em [`runtime-manifest.tsv`](runtime-manifest.tsv). O perfil portátil combina
Zulu OpenJDK 7u352 e H2 1.4.200, fixados separadamente em
[`portable-runtime-manifest.tsv`](portable-runtime-manifest.tsv). Os manifestos
são as autoridades de suas trilhas: um checksum informado localmente nunca
substitui o valor versionado.

No fechamento da fase 1, os dois manifestos, o `ojdbc7` externo e a instância
Oracle qualificada são reunidos no
[`manifesto congelado do baseline`](../../migration/baselines/01-legacy/README.md).

## Limite de confiança

- O Oracle JDK 7u80 é proprietário, obsoleto e obtido manualmente pelo usuário
  após autenticação e aceite da licença.
- Maven 3.8.9 está em fim de vida e é mantido somente porque executa com Java 7.
- WildFly 9.0.2.Final também está obsoleto, embora seja open source.
- Nenhum arquivo, diretório extraído ou imagem que incorpore o JDK 7 é
  versionado, publicado ou enviado ao GitHub Actions.
- O runtime é executado somente em host descartável, VM ou container local com
  bind em `127.0.0.1`, `localhost` ou `::1`.
- Zulu OpenJDK 7u352 e H2 1.4.200 também são EOL e existem somente para a
  trilha `portable-ci`; H2 fica em memória, sem console ou listener e fora do
  WAR.

## Layout externo

Use diretórios fora do checkout. O exemplo abaixo não é obrigatório, mas torna
os caminhos previsíveis:

```text
/opt/migration-lab/
├── archives/
│   ├── apache-maven-3.8.9-bin.tar.gz
│   ├── jdk-7u80-linux-x64.tar.gz
│   └── wildfly-9.0.2.Final.tar.gz
└── tools/
    ├── apache-maven-3.8.9/
    ├── jdk1.7.0_80/
    └── wildfly-9.0.2.Final/
```

Se `/opt` não estiver disponível, escolha outra pasta externa e use caminhos
absolutos no `.env`.

## Downloads oficiais

| Componente | Arquivo e endereço |
| --- | --- |
| Oracle JDK 7u80 | Página: <https://www.oracle.com/java/technologies/javase/javase7-archive-downloads.html><br>Origem autenticada: <https://download.oracle.com/otn/java/jdk/7u80-b15/jdk-7u80-linux-x64.tar.gz> |
| Apache Maven 3.8.9 | <https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/apache-maven-3.8.9-bin.tar.gz><br>SHA-512 publicado: <https://archive.apache.org/dist/maven/maven-3/3.8.9/binaries/apache-maven-3.8.9-bin.tar.gz.sha512> |
| WildFly 9.0.2.Final Full/Web | <https://download.jboss.org/wildfly/9.0.2.Final/wildfly-9.0.2.Final.tar.gz> |

Na página da Oracle, escolha **Java SE Development Kit 7u80 → Linux x64 →
146.42 MB → `jdk-7u80-linux-x64.tar.gz`**. Não escolha o JRE, o Server JRE, o
RPM ou a versão x86. O link direto só funciona depois do aceite da licença e da
autenticação. Não forneça as credenciais ao projeto.

Checksums já fixados:

```text
Oracle JDK 7u80 SHA-256:
bad9a731639655118740bee119139c1ed019737ec802a630dd7ad7aab4309623

Maven 3.8.9 SHA-256:
3e4c68cdd70f96635e713f36c8fc3ea3182035245d3da2156576710ca0fe4b0c

Maven 3.8.9 SHA-512:
4a490b7f331a0e7869b61da24600241e445339f2801ed94e32f835b63ed78597ad05ef8c1cce2501b4c2c3dcde30030eb395cd5756be739c20ac687ad6f82f0e

WildFly 9.0.2.Final SHA-256:
74689569d6e04402abb7d94921c558940725d8065dce21a2d7194fa354249bb6
```

O SHA-256 do JDK foi calculado sobre o arquivo licenciado de 153.530.841 bytes
fornecido localmente e aprovado pelo projeto. A Oracle não publica um digest
desse arquivo na página de download; por isso, esse valor registra a
distribuição efetivamente validada pelo laboratório, não uma assinatura
publicada pelo fornecedor.

## Fornecimento

1. Baixe `jdk-7u80-linux-x64.tar.gz` na
   [página de arquivo do Java SE 7 da Oracle][oracle-jdk]. Não compartilhe as
   credenciais usadas no download.
2. Baixe Maven e WildFly somente pelas URLs registradas no manifesto.
3. Execute `sha256sum` sobre cada arquivo e compare manualmente o resultado com
   o manifesto. Para o Maven, valide também o arquivo `.sha512` da Apache.
4. Extraia os três arquivos fora do checkout, sem usar `sudo` quando o
   diretório escolhido já pertencer ao usuário.
5. Copie `.env.example` para `.env`, configure os seis caminhos legados e
   execute `./scripts/doctor.sh CP-1B --env .env`.

Depois do fornecimento, use o
[runbook da aplicação legada](../../docs/legacy-application-runbook.md) para
diagnóstico do CP-1E, build, inicialização, testes manuais, stop e limpeza.
Este documento permanece como fonte de downloads, licenças e checksums.

A partir do CP-1C, configure também `JAVA7_TRUSTSTORE` com um JKS atualizado
fornecido pelo sistema. O Java 7u80 precisa de TLS 1.2 explícito e seu truststore
original não reconhece a cadeia atual do Maven Central. A correção validada está
em `migration/steps/CP-1C-legacy-build-https.md`; não use opções Maven que
desabilitem a validação HTTPS.

A Oracle não publica um checksum para o JDK 7u80 na página de arquivo. O
responsável pelo laboratório forneceu o arquivo licenciado, e seu digest foi
calculado localmente, revisado e fixado no manifesto. O diagnóstico rejeita
qualquer outro conteúdo, mesmo que o arquivo tenha o mesmo nome.

O Maven publicado pela Apache inclui SHA-512 oficial; além dessa verificação, o
manifesto registra SHA-256 para manter uma validação uniforme dos três
artefatos. O SHA-256 do WildFly foi calculado diretamente sobre a distribuição
oficial indicada no manifesto.

## Extração depois da validação manual

Após os digests dos arquivos corresponderem ao manifesto:

```bash
tar -xzf /opt/migration-lab/archives/jdk-7u80-linux-x64.tar.gz \
  -C /opt/migration-lab/tools
tar -xzf /opt/migration-lab/archives/apache-maven-3.8.9-bin.tar.gz \
  -C /opt/migration-lab/tools
tar -xzf /opt/migration-lab/archives/wildfly-9.0.2.Final.tar.gz \
  -C /opt/migration-lab/tools
```

Execute o `doctor` depois da extração. Ele confirma os executáveis e as versões
efetivas, força o Maven legado a executar com `JAVA7_HOME`, registra a origem e
o digest observados e rejeita bind público.

O tarball do WildFly não materializa necessariamente o diretório vazio de log.
Prepare-o antes da primeira execução:

```bash
install -d -m 0755 \
  /opt/migration-lab/tools/wildfly-9.0.2.Final/standalone/log
```

Não publique uma imagem de container criada com o Oracle JDK. Caso o baseline
seja encapsulado futuramente, a construção deverá ocorrer localmente com o JDK
fornecido como entrada externa e a imagem deverá permanecer privada no host.

[oracle-jdk]: https://www.oracle.com/java/technologies/javase/javase7-archive-downloads.html

## Runtime portátil do CP-1D

O CI usa `zulu7.56.0.11-ca-jdk7.0.352-linux_x64.tar.gz`, sob GPLv2 com
Classpath Exception, e `h2-1.4.200.jar`, sob MPL 2.0 ou EPL 1.0. Ambos são
baixados de origens oficiais, validados pelos SHA-256 do manifesto portátil e
mantidos fora do checkout.

Essa combinação executou Maven 3.8.9 e o H2 em `MODE=Oracle` tanto no Zulu
7u352 quanto no Oracle JDK 7u80. Isso comprova apenas que o runtime inicia. A
qualificação oficial continua sendo Oracle JDK 7u80, `ojdbc7` e Oracle 19c na
rede interna.

Consulte [a decisão do CP-1D](../../docs/cp-1d-runtime-selection.md) antes de
fornecer ou atualizar qualquer um desses artefatos.
