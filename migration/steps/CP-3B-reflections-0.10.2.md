# CP-3B — atualizar Reflections e preservar a descoberta anotada

## Risco isolado

Reflections 0.9.10 usa scanners e transitivas antigas. A linha 0.10 alterou a
configuração de scanners e pode devolver conjunto vazio quando a resolução de
URLs ou classloaders fica implícita no artefato implantado.

## Menor correção

1. Fixar Reflections 0.10.2.
2. Marcar os validadores concretos com `@Validator` em runtime.
3. Configurar `TypesAnnotated`, `SubTypes`, URLs, filtro e TCCL explicitamente.
4. Filtrar tipos inelegíveis e preservar a ordenação fora da biblioteca.
5. Auditar as novas transitivas e executar a sonda no classloader real do
   WildFly 26 nos perfis H2 e Oracle.

## Verificação

O resultado só é aprovado quando os dois perfis encontram as mesmas três
classes, produzem a ordem `numero-formato,valor-monetario,status-inicial`,
rejeitam o XML com status diferente de `NOVO` e usam
`org.jboss.modules.ModuleClassLoader` sem erro de linkage.

## Rollback

Voltar ao commit verde `28789b65964b6daf79082179893687140b84493b`
restaura apenas Reflections 0.9.10, Guava 15.0, Javassist 3.19.0-GA e FindBugs
annotations 2.0.1. A mudança não altera schema nem dados permanentes.
