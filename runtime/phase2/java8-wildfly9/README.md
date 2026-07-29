# CP-2A — Java 8 no WildFly 9

O CP-2A mantém WildFly 9.0.2.Final, Maven 3.8.9, H2 1.4.200,
`ojdbc7`, as dependências legadas e os pacotes `javax.*`. A única mudança de
plataforma aprovada neste checkpoint é de Java 7 para Eclipse Temurin
OpenJDK 8u492-b09.

O arquivo oficial fixado é:

- origem:
  <https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u492-b09/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz>;
- release:
  <https://github.com/adoptium/temurin8-binaries/releases/tag/jdk8u492-b09>;
- licença: `GPL-2.0-only WITH Classpath-exception-2.0`;
- SHA-256:
  `da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e`.

O link contém a versão no caminho e não é uma referência flutuante. Confirme o
digest antes de extrair o arquivo fora do checkout.

```bash
sha256sum OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz
tar -xzf OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz \
  -C /opt/migration-lab/tools
```

Configure em `.env`:

```dotenv
JAVA8_HOME=/opt/migration-lab/tools/jdk8u492-b09
JAVA8_ARCHIVE=/opt/migration-lab/archives/OpenJDK8U-jdk_x64_linux_hotspot_8u492b09.tar.gz
JAVA8_ARCHIVE_SHA256=da257f161d7f8c6ca5b0e5d9e4090f65ac28c5e398072e68b8ae87988b1d1a2e
```

O manifesto desta pasta é a fonte de verdade legível por máquina. Os
manifestos de `runtime/legacy/` continuam imutáveis para a reprodução da tag
`migration/01-legacy-baseline`.
