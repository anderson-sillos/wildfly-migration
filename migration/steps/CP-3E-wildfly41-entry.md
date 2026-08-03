# INC-015 / CP-3E — WAR EE 8 não inicia no WildFly 41

## Identificação

- checkpoint: `CP-3E`;
- estado verde de origem: `CP-3D`, WAR SHA-256
  `0e431a2ec85e0918cc89ed91dcec5715e7872e18b8d57441d7ae781b4a5a5d5b`;
- runtime de destino: Eclipse Temurin OpenJDK `21.0.12+8` e WildFly Community
  `41.0.0.Final`;
- etapa: `deployment`;
- categoria: namespace/classloader;
- reprodução: `natural`;
- perfis afetados: a tentativa é comum aos perfis; o datasource ainda não foi
  qualificado neste diagnóstico.

## Tentativa antes da correção

O runtime foi instalado conforme o manifesto do gate. A tentativa foi
executada sem editar `app/`, `web.xml` ou o WAR:

```bash
./scripts/build-cp-3b.sh --profile ci-h2 --env .env --ide-rebuild
./scripts/diagnose-cp-3e-unchanged.sh \
  --env .env \
  --war app/target/wildfly-migration.war \
  --result migration/evidence/CP-3E/unchanged-war.json \
  --diagnostic-log migration/evidence/CP-3E/unchanged-war-server.txt
```

O servidor subiu em loopback. O comando de deploy foi rejeitado e o WildFly
desfez o deployment. O resultado legível por máquina e o log sanitizado estão
em `migration/evidence/CP-3E/`.

## Assinatura sanitizada

```text
WFLYCTL0080: Failed services
Caused by: java.lang.NoClassDefFoundError: ... javax/servlet/http/HttpServlet
Caused by: java.lang.ClassNotFoundException: javax.servlet.http.HttpServlet
```

O mesmo padrão aparece para `javax.servlet.Filter` e para
`javax.servlet.jsp.tagext.TryCatchFinally` usado pelos handlers Tiles.

## Causa-raiz

WildFly 41 executa o modelo Jakarta EE e não oferece os módulos EE 8 com
pacotes `javax.servlet*` exigidos pelo WAR do CP-3D. O bytecode Java 17 foi
aceito pela JVM 21; a falha é de linkage entre o namespace da aplicação e o
namespace do servidor, não uma limitação da linguagem Java.

O datasource, logging e Oracle não são considerados aprovados ou reprovados
por esta tentativa: a falha ocorre antes de o fluxo web alcançar esses
componentes. A observação separada está em
`compatibility-observations.tsv`.

## Menor correção e fronteira

O CP-3E troca primeiro a API `provided` para Jakarta EE Web Profile 11. A
migração dos imports, descritores, JSPs e TLD é deliberadamente o CP-3F; Tiles,
Commons FileUpload, Reflections e a ponte de logging permanecem para os gates
seguintes, cada um com evidência própria.

## Aplicação equivalente no sistema real

1. gere o WAR aprovado do último checkpoint sem transformação;
2. execute-o no WildFly/Jakarta de destino em um runtime isolado;
3. preserve a primeira causa `ClassNotFoundException` e o componente que a
   referencia, sem “resolver” empacotando APIs fornecidas pelo servidor;
4. separe falhas de namespace de datasource, segurança e bibliotecas e migre-as
   em commits reversíveis.

## Teste de regressão e rollback

O script `diagnose-cp-3e-unchanged.sh` deve continuar reproduzindo a rejeição
somente enquanto o WAR ainda for o estado EE 8. Depois da correção, o teste de
entrada deixa de ser um critério verde e a validação deve usar os contratos do
CP-3F. O rollback retorna ao commit integrado do CP-3D e ao runtime Java 17 /
WildFly 26, sem alterar dados Oracle.
