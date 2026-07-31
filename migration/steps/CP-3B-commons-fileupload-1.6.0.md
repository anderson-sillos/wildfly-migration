# CP-3B — atualizar Commons FileUpload sem migrar o namespace

## Risco isolado

FileUpload 1.2.2 e Commons IO 1.3.2 permaneciam no WAR depois da transição
para Java 17. A atualização precisa corrigir essa dívida sem misturar a troca
de `javax.servlet` para `jakarta.servlet` nem a substituição arquitetural do
parser multipart.

## Menor correção

1. Fixar FileUpload 1.6.0 e Commons IO 2.19.0 no POM.
2. Preservar as chamadas da linha 1.x e os limites existentes.
3. Manter as APIs Servlet como `provided` pelo WildFly.
4. Auditar o WAR e conservar intacta a allowlist histórica da fase 2.
5. Repetir upload válido, metadados, limites por arquivo/requisição e
   limpeza de temporários nos perfis H2 e Oracle.

## Rollback

Voltar ao commit verde da atividade 3.7
`e73f3184917984062d9ce8037d75236631399d99` restaura somente FileUpload
1.2.2 e Commons IO 1.3.2. A troca não altera schema nem dados permanentes.
