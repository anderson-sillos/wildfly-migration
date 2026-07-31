# CP-3B — Reflections 0.10.2 como ponte

## Decisão da atividade 3.9

O gate Java 17/WildFly 26 atualiza
`org.reflections:reflections` de 0.9.10 para 0.10.2. Esta é uma ponte para
reduzir o risco imediato sem antecipar o `ServletContainerInitializer` da
atividade 3.33.

A descoberta passa a representar o uso da aplicação real: as implementações
concretas de `PedidoImportValidator` recebem `@Validator`, e
`LegacyValidatorDiscovery` usa
`getTypesAnnotatedWith(Validator.class)`. A annotation possui retenção em
runtime e alvo de tipo. Interfaces, classes abstratas e classes anotadas que
não implementem o contrato continuam inelegíveis.

## Configuração explícita do classloader

Reflections 0.10.2 mudou a API de scanners. A ponte configura explicitamente:

- as URLs do pacote de validação resolvidas pelo TCCL do WAR;
- filtro restrito ao mesmo pacote;
- `Scanners.TypesAnnotated` e `Scanners.SubTypes`, exigidos pela consulta de
  tipos anotados;
- o próprio TCCL para resolução das classes.

Essa configuração evita depender do construtor abreviado que possui um
[relato de descoberta divergente em JAR na versão 0.10.2](https://github.com/ronmamo/reflections/issues/373).
A [implementação oficial 0.10.2](https://github.com/ronmamo/reflections/blob/0.10.2/src/main/java/org/reflections/Reflections.java)
documenta que `getTypesAnnotatedWith` depende dos scanners de annotations e
subtipos.

No WildFly 26, a sonda exige o TCCL
`org.jboss.modules.ModuleClassLoader`, o conjunto exato das três classes e a
ordem funcional:

1. `numero-formato`;
2. `valor-monetario`;
3. `status-inicial`.

O conjunto é comparado por nomes completos em ordem alfabética; a execução é
ordenada por `order()` e, em empate, pelo nome completo da classe. Assim, a
ordem não depende da iteração do `Set` devolvido pela biblioteca.

## Transitivas e empacotamento

O POM publicado da 0.10.2 substitui as transitivas antigas por Javassist
3.28.0-GA e JSR-305 3.0.2. Guava 15.0 e FindBugs annotations 2.0.1 deixam o
WAR. A dependência transitiva SLF4J é excluída do Reflections porque a API
1.7.36 já está declarada como `provided` e é fornecida pelo WildFly.

A allowlist da fase 2 permanece imutável. Somente a allowlist ativa do gate
Java 17 aceita:

- `reflections-0.10.2.jar`;
- `javassist-3.28.0-GA.jar`;
- `jsr305-3.0.2.jar`.

## Qualificação

```bash
./scripts/qualify-cp-3b-h2.sh --env .env --non-interactive
./scripts/qualify-cp-3b-oracle.sh --env .env --non-interactive
```

As duas trilhas validam o classloader real do WildFly, scanners, annotation,
conjunto, ordem, rejeição funcional e conteúdo do WAR. Os relatórios
`cp-3b-discovery-ci-h2.json` e `cp-3b-discovery-oracle.json` são sanitizados.

## Limite da ponte

O resultado comprova o pacote e o WAR deste laboratório. Aplicações reais
precisam repetir a sonda para validators em outros módulos, JARs internos,
EARs, classloaders filhos ou pacotes adicionais.

Reflections 0.10.2 não é o destino final. A atividade 3.33 usará
`ServletContainerInitializer` com `@HandlesTypes(Validator.class)` e uma
fachada própria, preservando este conjunto e esta ordem sem biblioteca externa
de scanning.

## Rollback

O commit verde anterior é `28789b65964b6daf79082179893687140b84493b`.
Ele mantém MyBatis, logging e FileUpload já modernizados e restaura somente
Reflections 0.9.10 e suas transitivas.
