# CP-1C — Compatibilidade do build Java 7 com HTTPS atual

Este registro preserva as falhas observadas antes da correção. Elas são parte
do laboratório porque uma aplicação Java 7 real pode depender de um
repositório HTTPS cuja infraestrutura mudou depois do fim de suporte da JVM.

## Tentativa 1 — protocolo HTTPS

O Maven 3.8.9 foi executado inicialmente com o Oracle JDK 7u80, sem opções
adicionais. Nenhum plugin foi resolvido e o Maven relatou falha de transferência
para `https://repo.maven.apache.org/maven2`.

### Causa

O cliente TLS legado não selecionou por padrão o protocolo exigido pelo endpoint
atual. O Java 7u80 implementa TLS 1.2, mas o build precisa habilitá-lo
explicitamente para esta conexão.

### Correção

O wrapper define somente para o processo Maven:

```text
-Dhttps.protocols=TLSv1.2
```

HTTP, mirrors inseguros e opções que desabilitam validação TLS são proibidos.

## Tentativa 2 — cadeia de confiança

Com TLS 1.2 habilitado, o erro passou a ser explícito:

```text
sun.security.validator.ValidatorException: PKIX path building failed
sun.security.provider.certpath.SunCertPathBuilderException:
unable to find valid certification path to requested target
```

### Causa

O truststore distribuído com o JDK 7u80 em 2015 não contém uma cadeia de
confiança suficiente para o certificado atual do Maven Central.

### Correção

O JDK legado usa um truststore JKS atualizado fornecido pelo sistema operacional
e informado por `JAVA7_TRUSTSTORE`. No host de referência:

```text
/etc/ssl/certs/java/cacerts
```

Antes do build, o `doctor` exige que esse arquivo seja legível pelo `keytool` do
próprio Java 7. O wrapper configura:

```text
-Djavax.net.ssl.trustStore=<JAVA7_TRUSTSTORE>
-Djavax.net.ssl.trustStorePassword=changeit
```

Isso mantém validação de cadeia e hostname. O projeto não altera o JDK
proprietário, não baixa certificados sem revisão e não versiona um truststore.
Em outro sistema operacional, gere ou selecione um JKS atualizado e registre
sua origem fora do checkout.

## Descoberta adicional — plugin Enforcer

Depois de resolver HTTPS, `maven-enforcer-plugin:3.0.0` falhou com:

```text
Unsupported major.minor version 52.0
```

Essa release exige Java 8. O baseline usa `3.0.0-M3`, última release da linha
declarada compatível com Java 7, mantendo as regras que exigem Maven 3.8.9 e JVM
7 no build.

## Verificação

Com as três decisões acima, o Maven resolveu os artefatos somente via Maven
Central, compilou o marcador com major version 51 e gerou o WAR auditável.

```bash
./scripts/build-cp-1c.sh --env .env
```

## Rollback

Remova `JAVA7_TRUSTSTORE` do ambiente e reverta o wrapper/POM pelo Git. Isso
restaura a falha original, mas não altera o truststore do sistema nem o JDK. Não
substitua o rollback por `-Dmaven.wagon.http.ssl.insecure=true`,
`-Dmaven.wagon.http.ssl.allowall=true` ou repositórios HTTP.
