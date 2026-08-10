## Why

O laboratório produziu evidências técnicas extensas, mas ainda não existe uma narrativa curta e orientada à decisão que permita a gerentes e diretores compreender o risco do legado, a proposta, os resultados comprovados e como aplicar o método em uma migração real. A apresentação também deve tornar visível como o projeto foi integralmente construído com uso de IA por meio do Codex e organizado por SDD com OpenSpec, sem confundir automação com ausência de direção e validação humana.

## What Changes

- Criar uma apresentação textual executiva com duração máxima de 20 minutos, sem limitar previamente a quantidade de slides.
- Organizar a narrativa em três partes:
  - problema/risco, proposta do laboratório, Codex/SDD/OpenSpec e planejamento em três fases;
  - constatações comprovadas, incompatibilidades/correções, decisões por componente e lições aprendidas;
  - aplicação em uma migração real, próximos passos e decisões da liderança.
- Incluir o quadro WildFly × Java como evidência do risco de ciclo de vida, compatibilidade e necessidade de gates.
- Explicar resumidamente SDD (*Specification-Driven Development*) e o papel do OpenSpec na transformação de proposta, design, requisitos e tarefas em execução rastreável.
- Destacar que código, automações, documentação, evidências e planejamento foram construídos com Codex, sob direção, revisão e validação humana.
- Listar os principais componentes e bibliotecas do legado, apresentando a decisão tomada para cada um no destino.
- Definir para cada slide título, tempo-alvo, mensagem principal, texto básico e orientação breve para o apresentador.
- Manter as fontes que sustentam os slides em uma seção editorial separada, fora do conteúdo da apresentação.
- Distinguir claramente fatos comprovados pelo laboratório, recomendações derivadas e limitações do escopo.
- Encerrar com próximos passos e decisões esperadas da liderança.
- Manter fora do escopo o arquivo visual final, identidade visual, imagens, gráficos definitivos, animações e escolha da ferramenta de apresentação.

## Capabilities

### New Capabilities

- `executive-migration-presentation`: Define a narrativa executiva em três partes, o conteúdo básico dos slides, o quadro de compatibilidade, a explicação Codex/SDD/OpenSpec, as decisões por componente, a rastreabilidade das afirmações e os critérios de revisão.

### Modified Capabilities

Nenhuma capability existente terá seus requisitos alterados.

## Impact

- Material textual em `docs/presentation/`, sem alteração na aplicação, runtimes, banco de dados, APIs ou dependências.
- Uso de `docs/project-conclusion.md`, `docs/wildfly-java-compatibility.md`, evidências dos checkpoints, catálogo de incompatibilidades, histórico Codex/OpenSpec e specs principais como fontes verificáveis.
- Reorganização do conteúdo já produzido na change, com reabertura das tarefas editoriais afetadas.
- Revisão futura por responsáveis técnicos e representantes de negócio antes da conversão para formato visual.
