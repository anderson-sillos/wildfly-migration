import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const OUT_DIR = process.env.PRESENTATION_OUTPUT_DIR
  ? path.resolve(process.env.PRESENTATION_OUTPUT_DIR)
  : path.resolve("target/presentation/executive-migration-lab");
const FINAL_PPTX = process.env.PRESENTATION_FINAL_PPTX
  ? path.resolve(process.env.PRESENTATION_FINAL_PPTX)
  : path.join(SCRIPT_DIR, "executive-migration-lab.pptx");

const C = {
  canvas: "#FFFFFF",
  ink: "#0B0C0E",
  muted: "#5C6370",
  faint: "#8A909A",
  panel: "#F1F2F4",
  panel2: "#E8EAED",
  rule: "#C4C8CE",
  blue: "#3D8DFF",
  blueDark: "#175EBB",
  bluePale: "#EAF4FF",
  amber: "#B96A00",
  amberPale: "#FFF4D6",
  red: "#B4232F",
  redPale: "#FDECEE",
  green: "#19734A",
  greenPale: "#E8F6EF",
};

const FONT = "Arial";
const SLIDE_W = 1280;
const SLIDE_H = 720;
const M = 42;

const BASE = "https://github.com/anderson-sillos/wildfly-migration/blob/main/";
const RAW = "https://raw.githubusercontent.com/anderson-sillos/wildfly-migration/refs/heads/main/docs/presentation/executive-migration-lab.md";

function pos(left, top, width, height) {
  return { left, top, width, height };
}

function addText(slide, value, position, options = {}) {
  const box = slide.shapes.add({
    geometry: "textbox",
    name: options.name,
    position,
    fill: options.fill ?? "none",
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
  });
  box.text = value;
  box.text.style = {
    fontSize: options.fontSize ?? 20,
    typeface: options.typeface ?? FONT,
    color: options.color ?? C.ink,
    bold: options.bold ?? false,
    italic: options.italic ?? false,
    alignment: options.alignment ?? "left",
    verticalAlignment: options.verticalAlignment ?? "top",
    wrap: options.wrap ?? "square",
    autoFit: options.autoFit ?? "shrinkText",
    lineSpacing: options.lineSpacing,
    insets: options.insets ?? { top: 0, right: 0, bottom: 0, left: 0 },
  };
  return box;
}

function addRect(slide, position, options = {}) {
  return slide.shapes.add({
    geometry: options.geometry ?? "rect",
    name: options.name,
    position,
    fill: options.fill ?? C.panel,
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
    borderRadius: options.borderRadius,
  });
}

function addLine(slide, left, top, width, options = {}) {
  return slide.shapes.add({
    geometry: "line",
    name: options.name,
    position: { left, top, width, height: options.height ?? 0 },
    fill: "none",
    line: {
      style: options.style ?? "solid",
      fill: options.color ?? C.rule,
      width: options.weight ?? 1,
      beginArrowType: options.beginArrowType,
      endArrowType: options.endArrowType,
    },
  });
}

function addCircle(slide, left, top, size, options = {}) {
  return slide.shapes.add({
    geometry: "ellipse",
    position: { left, top, width: size, height: size },
    fill: options.fill ?? C.ink,
    line: options.line ?? { style: "solid", fill: "none", width: 0 },
  });
}

function addFooter(slide, number, section) {
  addLine(slide, M, 666, SLIDE_W - 2 * M, { color: C.rule, weight: 1 });
  addText(slide, section.toUpperCase(), pos(M, 674, 620, 24), {
    fontSize: 12,
    bold: true,
    color: C.faint,
    autoFit: "shrinkText",
  });
  addText(slide, String(number).padStart(2, "0"), pos(1160, 674, 78, 24), {
    fontSize: 12,
    bold: true,
    color: C.faint,
    alignment: "right",
    autoFit: "shrinkText",
  });
}

function addTitle(slide, title, options = {}) {
  addText(slide, title, pos(M, 36, options.width ?? 1120, 60), {
    name: `title-${title.slice(0, 20)}`,
    fontSize: options.fontSize ?? 48,
    bold: true,
    color: C.ink,
    autoFit: "shrinkText",
    verticalAlignment: "middle",
  });
}

function addStatus(slide, label, kind = "proof", options = {}) {
  const map = {
    proof: { color: C.blueDark, line: C.blue },
    recommendation: { color: C.amber, line: C.amber },
    limitation: { color: C.muted, line: C.faint },
  };
  const s = map[kind];
  addLine(slide, M, options.top ?? 111, 34, { color: s.line, weight: 3 });
  addText(slide, label.toUpperCase(), pos(M + 46, (options.top ?? 111) - 8, options.width ?? 650, 24), {
    fontSize: 14,
    bold: true,
    color: s.color,
    autoFit: "none",
    verticalAlignment: "middle",
  });
}

function addCallout(slide, label, textValue, position, kind = "proof", options = {}) {
  const map = {
    proof: { fill: C.bluePale, accent: C.blueDark },
    recommendation: { fill: C.amberPale, accent: C.amber },
    limitation: { fill: C.panel, accent: C.muted },
  };
  const s = map[kind];
  addRect(slide, position, { fill: options.fill ?? s.fill });
  addRect(slide, pos(position.left, position.top, 6, position.height), { fill: s.accent });
  if (position.height <= 60) {
    addText(slide, label.toUpperCase(), pos(position.left + 22, position.top + 12, 165, position.height - 24), {
      fontSize: 13,
      bold: true,
      color: s.accent,
      autoFit: "none",
      verticalAlignment: "middle",
    });
    addText(slide, textValue, pos(position.left + 185, position.top + 10, position.width - 205, position.height - 20), {
      fontSize: options.fontSize ?? 16,
      bold: options.bold ?? false,
      color: C.ink,
      verticalAlignment: "middle",
    });
    return;
  }
  addText(slide, label.toUpperCase(), pos(position.left + 22, position.top + 10, 180, 18), {
    fontSize: 13,
    bold: true,
    color: s.accent,
    autoFit: "none",
  });
  addText(slide, textValue, pos(position.left + 22, position.top + 30, position.width - 40, position.height - 38), {
    fontSize: options.fontSize ?? 18,
    bold: options.bold ?? false,
    color: C.ink,
    verticalAlignment: options.verticalAlignment ?? "top",
  });
}

function bulletParagraphs(items) {
  return items.map((item) => {
    if (typeof item === "string") {
      return { bulletCharacter: "•", marginLeft: 20, indent: -12, runs: [item], spaceAfter: 8 };
    }
    return {
      bulletCharacter: "•",
      marginLeft: 20,
      indent: -12,
      runs: [
        { run: item.lead, textStyle: { bold: true } },
        item.text,
      ],
      spaceAfter: item.spaceAfter ?? 8,
    };
  });
}

function addBulletList(slide, items, position, options = {}) {
  return addText(slide, bulletParagraphs(items), position, {
    fontSize: options.fontSize ?? 20,
    color: options.color ?? C.ink,
    autoFit: options.autoFit ?? "shrinkText",
    lineSpacing: options.lineSpacing ?? 1.08,
  });
}

function addTable(slide, values, position, columnWidths, options = {}) {
  const table = slide.tables.add({
    rows: values.length,
    columns: values[0].length,
    left: position.left,
    top: position.top,
    width: position.width,
    height: position.height,
    columnWidths,
    values,
  });
  table.borders.assign({ style: "solid", fill: C.rule, width: 1 });

  const all = table.cells.block({ row: 0, column: 0, rowCount: values.length, columnCount: values[0].length });
  all.assign({
    textStyle: { fontSize: options.fontSize ?? 13, color: C.ink, typeface: FONT },
    margins: { top: options.marginY ?? 5, right: 7, bottom: options.marginY ?? 5, left: 7 },
  });

  const header = table.cells.block({ row: 0, column: 0, rowCount: 1, columnCount: values[0].length });
  header.assign({
    fill: options.headerFill ?? C.ink,
    textStyle: { fontSize: options.headerFontSize ?? 14, color: C.canvas, bold: true, typeface: FONT },
    margins: { top: 6, right: 7, bottom: 6, left: 7 },
  });

  for (let row = 1; row < values.length; row += 1) {
    const range = table.cells.block({ row, column: 0, rowCount: 1, columnCount: values[0].length });
    range.assign({ fill: row % 2 === 0 ? "#F8F8F9" : C.canvas });
  }
  return table;
}

function highlightTableRow(table, row, columns, fill, color = C.ink, bold = false) {
  const range = table.cells.block({ row, column: 0, rowCount: 1, columnCount: columns });
  range.assign({
    fill,
    textStyle: { color, bold, typeface: FONT },
  });
}

function setNotes(slide, time, message, talk, sources) {
  const text = [
    `Tempo-alvo: ${time}`,
    "",
    `Mensagem central: ${message}`,
    "",
    "Notas do apresentador:",
    talk,
    "",
    "[Sources]",
    ...sources.map((source) => `- ${source}`),
  ].join("\n");
  slide.speakerNotes.textFrame.setText(text);
  slide.speakerNotes.setVisible(true);
}

function newSlide() {
  const slide = presentation.slides.add();
  slide.background.fill = C.canvas;
  return slide;
}

const presentation = Presentation.create({ slideSize: { width: SLIDE_W, height: SLIDE_H } });

// Slide 1 — cover (Codex Grid: sparse stacked text flow)
{
  const slide = newSlide();
  addText(slide, "LABORATÓRIO EXECUTIVO", pos(M, 40, 420, 26), {
    fontSize: 16,
    bold: true,
    color: C.blueDark,
    autoFit: "none",
  });
  addRect(slide, pos(M, 104, 8, 290), { fill: C.blue });
  addText(slide, "Modernizar\ncom controle", pos(M + 34, 120, 860, 230), {
    fontSize: 76,
    bold: true,
    color: C.ink,
    lineSpacing: 0.92,
    autoFit: "none",
    verticalAlignment: "middle",
  });
  addText(slide, "Do Java 7 e WildFly 9 ao OpenJDK 25, WildFly 41 e Jakarta EE 11", pos(M + 34, 372, 910, 70), {
    fontSize: 27,
    color: C.muted,
    autoFit: "shrinkText",
  });
  addLine(slide, M + 34, 485, 1040, { color: C.rule, weight: 1 });
  addText(slide, "UMA APLICAÇÃO", pos(M + 34, 518, 250, 22), { fontSize: 14, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "TRÊS FASES", pos(430, 518, 250, 22), { fontSize: 14, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "ESTADOS APROVADOS", pos(820, 518, 300, 22), { fontSize: 14, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "Preservar contratos", pos(M + 34, 548, 280, 32), { fontSize: 22, bold: true });
  addText(slide, "Separar os riscos", pos(430, 548, 280, 32), { fontSize: 22, bold: true });
  addText(slide, "Provar e retornar", pos(820, 548, 300, 32), { fontSize: 22, bold: true });
  addText(slide, "Aplicar o método primeiro a um piloto controlado", pos(M + 34, 628, 900, 28), {
    fontSize: 18,
    bold: true,
    color: C.blueDark,
    autoFit: "none",
  });
  addText(slide, "Agosto de 2026", pos(1060, 638, 178, 20), { fontSize: 13, color: C.faint, alignment: "right", autoFit: "none" });
  setNotes(
    slide,
    "0min30s",
    "Comprovado no laboratório: uma aplicação web representativa evoluiu de Java 7 e WildFly 9 para OpenJDK 25, WildFly 41 e Jakarta EE 11, preservando seus contratos por uma migração incremental e verificável.",
    "Abrir com a tese e antecipar as três partes: por que o legado exige ação, o que o laboratório comprovou e como iniciar uma aplicação real. Não detalhar bibliotecas neste momento.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/evidence/CP-3K.md`],
  );
}

// Slide 2 — compatibility evidence table (Codex Grid: table-led evidence)
{
  const slide = newSlide();
  addTitle(slide, "Compatibilidade não é longevidade");
  addStatus(slide, "Recomendação para aplicação real", "recommendation");
  addText(slide, "Legado funcional não equivale a plataforma sustentável: ciclo de vida, compatibilidade e capacidade de atualização precisam ser avaliados juntos.", pos(M, 137, 1070, 38), {
    fontSize: 18,
    color: C.muted,
  });
  addText(slide, "Referência verificada em 30/07/2026", pos(990, 116, 248, 18), { fontSize: 12, color: C.faint, alignment: "right", autoFit: "none" });
  const values = [
    ["WildFly", "Java 7", "Java 8", "Java 11", "Java 17", "Java 21", "Java 25", "Plataforma padrão"],
    ["8–9", "Sim", "Sim", "N/Q", "N/Q", "N/Q", "N/Q", "Java EE 7"],
    ["10–13", "Não", "Sim", "N/Q", "N/Q", "N/Q", "N/Q", "Java EE 7; EE 8 em prévia no 13"],
    ["14", "Não", "Sim", "N/Q", "N/Q", "N/Q", "N/Q", "Java EE 8"],
    ["15–24", "Não", "Sim", "Rec.", "N/Q", "N/Q", "N/Q", "Java EE 8; Jakarta EE 8 a partir do 17.0.1"],
    ["25–26.1", "Não", "Sim", "Sim", "Sim", "N/Q", "N/Q", "Java EE 8 / Jakarta EE 8; APIs javax.*"],
    ["27–29", "Não", "Não", "Sim", "Rec.", "N/Q", "N/Q", "Jakarta EE 10"],
    ["30–31", "Não", "Não", "Sim", "Rec.", "Aval.", "N/Q", "Jakarta EE 10"],
    ["32", "Não", "Não", "Sim", "Sim", "Rec.", "N/Q", "Jakarta EE 10"],
    ["33–34", "Não", "Não", "Sim", "Sim", "Rec.", "N/Q", "Jakarta EE 10"],
    ["35–37", "Não", "Não", "Não", "Sim", "Rec.", "N/Q", "Jakarta EE 10"],
    ["38–39", "Não", "Não", "Não", "Sim", "Rec.", "Aval.", "Jakarta EE 10"],
    ["40–41", "Não", "Não", "Não", "Sim", "Sim", "Rec.", "Jakarta EE 11; variante EE 10 temporária"],
  ];
  const table = addTable(slide, values, pos(M, 188, 1196, 432), [100, 80, 80, 80, 80, 80, 80, 616], {
    fontSize: 12,
    headerFontSize: 13,
    marginY: 3,
  });
  highlightTableRow(table, 1, 8, C.redPale, C.red, true);
  highlightTableRow(table, 5, 8, C.amberPale, C.amber, true);
  highlightTableRow(table, 12, 8, C.bluePale, C.blueDark, true);
  addText(slide, "Sim = qualificada/documentada · Rec. = JDK preferido · Aval. = funciona, ainda em avaliação · N/Q = não qualificada/documentada · Não = removida ou abaixo do mínimo", pos(M, 633, 1170, 28), {
    fontSize: 11.5,
    color: C.muted,
    autoFit: "shrinkText",
  });
  addFooter(slide, 2, "Parte 1 · Problema, proposta e planejamento");
  setNotes(
    slide,
    "2min",
    "Recomendação: manter uma plataforma que inicia não significa manter uma plataforma sustentável; ciclo de vida, compatibilidade e capacidade de atualização precisam ser avaliados em conjunto.",
    "Não ler a tabela inteira. Destacar três linhas: WildFly 8–9 como legado, 25–26.1 como ponte compatível com Java 8/11/17 e APIs javax, e 40–41 como destino Jakarta EE 11 com Java 25 preferido. Explicar que Rec. descreve preferência de runtime, não certificação TCK no mesmo JDK. A matriz é uma fotografia histórica e deve ser verificada novamente antes de uma decisão real.",
    [RAW, `${BASE}docs/wildfly-java-compatibility.md`, `${BASE}docs/project-conclusion.md`],
  );
}

// Slide 3 — process sequence
{
  const slide = newSlide();
  addTitle(slide, "Estados verdes tornam cada falha diagnosticável");
  addStatus(slide, "Comprovado no laboratório", "proof");
  addText(slide, "Preservar primeiro o comportamento e mudar poucas dimensões por vez tornou cada avanço reversível.", pos(M, 139, 1050, 30), {
    fontSize: 20,
    color: C.muted,
  });

  const xs = [42, 288, 534, 780, 1026];
  addLine(slide, 102, 239, 1045, { color: C.rule, weight: 2 });
  for (const x of xs) addCircle(slide, x + 91, 229, 20, { fill: C.blue });
  const steps = [
    ["01", "Baseline auditável", "Reproduzir o legado e congelar contratos, artefato e configuração."],
    ["02", "Falha natural", "Executar o último estado verde no próximo runtime antes de corrigir."],
    ["03", "Gate isolado", "Separar JVM, servidor, dependências, Jakarta e banco."],
    ["04", "Mesmos contratos", "Repetir CI portátil e qualificação no Oracle."],
    ["05", "Checkpoint", "Registrar evidência, limitações, aprovação e rollback."],
  ];
  steps.forEach(([n, heading, body], i) => {
    const x = xs[i];
    addText(slide, n, pos(x, 188, 204, 25), { fontSize: 14, bold: true, color: C.blueDark, alignment: "center", autoFit: "none" });
    addRect(slide, pos(x, 276, 212, 232), { fill: i === 4 ? C.bluePale : C.panel });
    addText(slide, heading, pos(x + 18, 302, 176, 56), { fontSize: 23, bold: true, verticalAlignment: "middle" });
    addLine(slide, x + 18, 368, 48, { color: i === 4 ? C.blue : C.ink, weight: 2 });
    addText(slide, body, pos(x + 18, 389, 176, 94), { fontSize: 17, color: C.muted });
  });
  addCallout(slide, "Estado verde", "Versão integrada, reconstruível e aprovada pelos critérios daquele ponto — com uma causa investigável e um retorno conhecido.", pos(M, 542, 1196, 91), "proof", { fontSize: 18 });
  addFooter(slide, 3, "Parte 1 · Problema, proposta e planejamento");
  setNotes(
    slide,
    "1min30s",
    "Comprovado: congelar um baseline, executar o último estado aprovado no próximo runtime e separar riscos em gates controlados tornou as incompatibilidades diagnosticáveis e o avanço reversível.",
    "Estado verde é uma versão integrada, reconstruível e aprovada pelos critérios daquele ponto. A proposta não é multiplicar ambientes sem necessidade; é separar riscos suficientes para que uma falha tenha causa investigável e um retorno conhecido.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}openspec/specs/migration-compatibility-lab/spec.md`, `${BASE}docs/checkpoints.md`],
  );
}

// Slide 4 — Codex + specification flow
{
  const slide = newSlide();
  addTitle(slide, "IA acelerou; especificações mantiveram controle");
  addStatus(slide, "Comprovado no projeto", "proof");
  addLine(slide, 624, 165, 0, { height: 445, color: C.rule, weight: 1 });

  addText(slide, "Codex", pos(M, 176, 500, 52), { fontSize: 36, bold: true, color: C.blueDark, autoFit: "none" });
  addText(slide, "Planejou, implementou, diagnosticou, documentou e executou validações.", pos(M, 239, 500, 70), {
    fontSize: 23,
    bold: true,
  });
  addBulletList(slide, [
    { lead: "Direção humana: ", text: "objetivos, revisão de decisões e aprovação de checkpoints." },
    { lead: "Acessos controlados: ", text: "credenciais e ambientes fornecidos sob responsabilidade humana." },
    { lead: "Testes manuais: ", text: "execução e aceites complementaram a automação." },
  ], pos(M, 337, 520, 185), { fontSize: 19 });
  addText(slide, "IA produziu os artefatos; pessoas mantiveram decisão e responsabilidade.", pos(M, 548, 520, 54), {
    fontSize: 19,
    bold: true,
    color: C.muted,
  });

  addText(slide, "SDD + OpenSpec", pos(670, 176, 500, 52), { fontSize: 36, bold: true, autoFit: "none" });
  addText(slide, "A especificação definiu o comportamento esperado antes da conclusão da implementação.", pos(670, 234, 530, 55), {
    fontSize: 19,
    color: C.muted,
  });
  const flow = [
    ["01", "Proposta", "por que"],
    ["02", "Design", "como"],
    ["03", "Specs", "o que deve ser verdade"],
    ["04", "Tarefas", "execução"],
    ["05", "Evidências", "checkpoint"],
  ];
  flow.forEach(([n, label, desc], i) => {
    const y = 312 + i * 57;
    addLine(slide, 670, y + 47, 530, { color: C.rule, weight: 1 });
    addText(slide, n, pos(670, y, 46, 34), { fontSize: 14, bold: true, color: C.blueDark, verticalAlignment: "middle", autoFit: "none" });
    addText(slide, label, pos(725, y, 150, 34), { fontSize: 20, bold: true, verticalAlignment: "middle", autoFit: "none" });
    addText(slide, desc, pos(882, y, 318, 34), { fontSize: 17, color: C.muted, verticalAlignment: "middle", autoFit: "none" });
  });
  addCallout(slide, "Resultado", "Velocidade de execução com rastreabilidade, revisão e evidência reproduzível.", pos(660, 606, 548, 54), "proof", { fontSize: 16, verticalAlignment: "middle" });
  addFooter(slide, 4, "Parte 1 · Problema, proposta e planejamento");
  setNotes(
    slide,
    "2min",
    "Comprovado no projeto: planejamento, código, scripts, documentação e evidências foram construídos com o Codex, enquanto especificações, testes e aprovações humanas mantiveram direção e controle.",
    "SDD significa Specification-Driven Development: a especificação guia a implementação e fornece critérios verificáveis. OpenSpec organizou intenção, decisões, requisitos e tarefas; não substitui Git, CI ou testes. Integralmente construído com IA significa que os artefatos foram produzidos na interação com o Codex, não que a IA decidiu sozinha.",
    [RAW, `${BASE}docs/codex-handoff.md`, `${BASE}openspec/changes/archive/2026-08-07-create-java-web-migration-lab/`, `${BASE}openspec/specs/`, `${BASE}docs/github-workflow.md`],
  );
}

// Slide 5 — three-phase timeline cards (Codex Grid: timeline with cards)
{
  const slide = newSlide();
  addTitle(slide, "Três fases separaram estabilização e ruptura");
  addStatus(slide, "Comprovado no laboratório", "proof");

  const cards = [
    {
      x: 42, fill: C.panel, number: "FASE 1", title: "Baseline legado", runtime: "Java 7 · WildFly 9",
      body: "Reproduzir o estado inicial e congelar os contratos.", consequence: "Compra conhecimento e elimina ambiguidade.",
    },
    {
      x: 452, fill: C.amberPale, number: "FASE 2", title: "Ponte de baixo impacto", runtime: "Java 8 · WildFly 26",
      body: "Preservar javax e isolar JVM e servidor.", consequence: "Cria um ponto de estabilização.",
    },
    {
      x: 862, fill: C.bluePale, number: "FASE 3", title: "Destino final", runtime: "OpenJDK 25 · WildFly 41",
      body: "Modernizar dependências e migrar para Jakarta EE 11.", consequence: "Concentra a ruptura sobre bases conhecidas.",
    },
  ];
  addLine(slide, 98, 585, 1080, { color: C.ink, weight: 1 });
  [98, 508, 918].forEach((x) => addCircle(slide, x - 6, 579, 12, { fill: C.ink }));
  cards.forEach((card, i) => {
    addRect(slide, pos(card.x, 170, 376, 370), { fill: card.fill });
    addText(slide, card.number, pos(card.x + 28, 200, 310, 22), { fontSize: 14, bold: true, color: i === 2 ? C.blueDark : (i === 1 ? C.amber : C.faint), autoFit: "none" });
    addText(slide, card.title, pos(card.x + 28, 241, 320, 64), { fontSize: 28, bold: true, verticalAlignment: "middle" });
    addText(slide, card.runtime, pos(card.x + 28, 316, 320, 30), { fontSize: 18, bold: true, color: C.muted, autoFit: "none" });
    addLine(slide, card.x + 28, 365, 54, { color: i === 2 ? C.blue : (i === 1 ? C.amber : C.ink), weight: 2 });
    addText(slide, card.body, pos(card.x + 28, 390, 320, 70), { fontSize: 19 });
    addText(slide, card.consequence, pos(card.x + 28, 469, 320, 48), { fontSize: 16, bold: true, color: C.muted });
  });
  addText(slide, "Java 17", pos(665, 570, 110, 22), { fontSize: 13, bold: true, color: C.blueDark, alignment: "center", autoFit: "none" });
  addText(slide, "Java 21", pos(780, 570, 110, 22), { fontSize: 13, bold: true, color: C.blueDark, alignment: "center", autoFit: "none" });
  addText(slide, "gates técnicos da fase final", pos(665, 607, 225, 22), { fontSize: 13, color: C.muted, alignment: "center", autoFit: "none" });
  addFooter(slide, 5, "Parte 1 · Problema, proposta e planejamento");
  setNotes(
    slide,
    "1min30s",
    "Comprovado: as três fases separaram conhecimento do legado, modernização de baixo impacto e ruptura arquitetural, evitando que todos os riscos aparecessem no mesmo salto.",
    "A fase 1 compra conhecimento; a fase 2 reduz risco operacional sem reescrever namespaces; a fase 3 executa a ruptura necessária com bases mais estáveis. Java 17 e 21 foram gates técnicos da fase final. Em uma aplicação real, a ponte pode ser apenas um gate de engenharia se a plataforma intermediária não for adequada para produção.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/evidence/CP-3K.md`, `${BASE}docs/checkpoints.md`],
  );
}

// Slide 6 — quantified proof (Codex Grid: metric-led)
{
  const slide = newSlide();
  addTitle(slide, "Destino final comprovado, com limites explícitos");
  addStatus(slide, "Comprovado no laboratório", "proof", { top: 127 });
  addText(slide, "O mesmo artefato foi qualificado por trilhas independentes, com runtime, banco e evidências identificados.", pos(M, 151, 1100, 32), {
    fontSize: 20,
    color: C.muted,
  });
  const metrics = [
    { x: 42, stat: "14", title: "contratos preservados", body: "Do baseline legado até a evolução final." },
    { x: 452, stat: "15/15", title: "cenários no destino", body: "Inclui proteção de fragmentos web." },
    { x: 862, stat: "2", title: "JDKs, o mesmo WAR", body: "Executado em OpenJDK 21 e 25." },
  ];
  metrics.forEach((m, i) => {
    addRect(slide, pos(m.x, 202, 376, 278), { fill: i === 1 ? C.bluePale : C.panel });
    addText(slide, m.stat, pos(m.x + 28, 230, 320, 105), { fontSize: i === 1 ? 70 : 82, bold: true, color: i === 1 ? C.blueDark : C.ink, verticalAlignment: "bottom", autoFit: "none" });
    addText(slide, m.title, pos(m.x + 28, 346, 320, 38), { fontSize: 22, bold: true, autoFit: "shrinkText" });
    addText(slide, m.body, pos(m.x + 28, 403, 320, 46), { fontSize: 16, color: C.muted });
  });
  addText(slide, "TRILHA PORTÁTIL", pos(42, 504, 240, 19), { fontSize: 13, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "H2 · feedback rápido", pos(42, 530, 300, 28), { fontSize: 21, bold: true });
  addText(slide, "QUALIFICAÇÃO OFICIAL", pos(452, 504, 260, 19), { fontSize: 13, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "Oracle 19c RU 19.3", pos(452, 530, 300, 28), { fontSize: 21, bold: true });
  addText(slide, "REPRODUÇÃO FINAL", pos(862, 504, 240, 19), { fontSize: 13, bold: true, color: C.faint, autoFit: "none" });
  addText(slide, "Checkout limpo + auditoria", pos(862, 530, 340, 28), { fontSize: 21, bold: true });
  addCallout(slide, "Limitação", "15/15 comprova o escopo definido — não carga, cluster, failover, integrações não modeladas nem requisitos próprios de produção.", pos(M, 584, 1196, 72), "limitation", { fontSize: 16 });
  addFooter(slide, 6, "Parte 2 · Provas, correções e aprendizados");
  setNotes(
    slide,
    "1min30s",
    "Comprovado: a aplicação preservou o comportamento essencial até o destino final e foi qualificada por trilhas independentes, com limites explicitamente registrados.",
    "Separar velocidade de feedback e qualificação oficial. H2 acelera, mas não substitui Oracle. O valor da prova está em saber exatamente qual comportamento foi exercitado, em qual runtime, com qual artefato e banco — e também o que permaneceu fora do escopo.",
    [RAW, `${BASE}docs/evidence/CP-3K.md`, `${BASE}migration/evidence/CP-3K/reproduction-ci-h2.json`, `${BASE}migration/evidence/CP-3K/reproduction-oracle.json`, `${BASE}migration/evidence/CP-3K/closure.properties`],
  );
}

// Slide 7 — incompatibility method
{
  const slide = newSlide();
  addTitle(slide, "As correções cobriram toda a cadeia de entrega");
  addStatus(slide, "Comprovado no laboratório", "proof");
  addLine(slide, 476, 170, 0, { height: 445, color: C.rule, weight: 1 });

  addText(slide, "27", pos(M, 178, 360, 145), { fontSize: 126, bold: true, color: C.blueDark, verticalAlignment: "bottom", autoFit: "none" });
  addText(slide, "incompatibilidades", pos(M, 322, 360, 36), { fontSize: 28, bold: true, autoFit: "none" });
  addText(slide, "A variedade importa mais que a contagem.", pos(M, 374, 365, 45), { fontSize: 18, color: C.muted });
  const cats = ["Ambiente", "Build", "Código", "Namespace", "Servidor", "Classloader", "XML", "Banco"];
  cats.forEach((cat, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const x = M + col * 180;
    const y = 448 + row * 42;
    addLine(slide, x, y + 13, 18, { color: C.blue, weight: 2 });
    addText(slide, cat, pos(x + 28, y, 135, 26), { fontSize: 16, bold: true, verticalAlignment: "middle", autoFit: "none" });
  });

  const steps = [
    ["01", "Capturar", "Executar o último estado verde e registrar a falha natural."],
    ["02", "Classificar", "Separar toolchain, deployment, dependência, segurança e persistência."],
    ["03", "Corrigir", "Preservar o contrato funcional — não necessariamente a biblioteca antiga."],
    ["04", "Provar", "Repetir contratos e auditar o artefato realmente implantado."],
    ["05", "Documentar", "Ligar causa, decisão, evidência, limitação e rollback."],
  ];
  steps.forEach(([n, head, body], i) => {
    const y = 180 + i * 84;
    addLine(slide, 520, y + 72, 680, { color: C.rule, weight: 1 });
    addText(slide, n, pos(520, y, 50, 54), { fontSize: 16, bold: true, color: C.blueDark, verticalAlignment: "middle", autoFit: "none" });
    addText(slide, head, pos(582, y, 160, 31), { fontSize: 22, bold: true, autoFit: "none" });
    addText(slide, body, pos(582, y + 34, 618, 38), { fontSize: 16, color: C.muted });
  });
  addCallout(slide, "Rastreabilidade", "Falha anterior → correção aplicada → prova posterior", pos(520, 605, 680, 50), "proof", { fontSize: 16, verticalAlignment: "middle" });
  addFooter(slide, 7, "Parte 2 · Provas, correções e aprendizados");
  setNotes(
    slide,
    "1min30s",
    "Comprovado: 27 incompatibilidades alcançaram ambiente, build, código, namespace, servidor, classloader, configuração, XML e banco; cada correção foi ligada à falha anterior e a uma prova posterior.",
    "Um salto direto poderia apresentar um único deployment quebrado escondendo causas diferentes. O catálogo permite reaproveitar sinais e estratégias durante o inventário de outra aplicação.",
    [RAW, `${BASE}migration/incompatibility-catalog.md`, `${BASE}migration/incompatibilities.tsv`, `${BASE}docs/project-conclusion.md`],
  );
}

// Slide 8 — platform decision table
{
  const slide = newSlide();
  addTitle(slide, "Runtime e configuração integram a entrega");
  addStatus(slide, "Comprovado no laboratório", "proof");
  addText(slide, "A fronteira da aplicação permaneceu estável; runtime, driver, pool e configuração evoluíram de forma versionada e auditável.", pos(M, 137, 1100, 34), {
    fontSize: 18,
    color: C.muted,
  });
  const values = [
    ["Componente", "Origem", "Decisão no laboratório", "Destino e justificativa"],
    ["Java", "Oracle JDK 7u80", "Gates 8, 17 e 21; JVM final isolada", "Temurin OpenJDK 25; build final com --release 21"],
    ["Maven", "3.8.9", "Fixar a versão do Java 7; atualizar após estabilizar a ponte", "Maven 3.9.16; Maven 4 RC evitado"],
    ["WildFly", "9.0.2", "26.1.3 como ponte javax; 41 após o gate Jakarta", "WildFly Community 41; exige atualização contínua"],
    ["Plataforma web", "Java EE 7; Servlet 2.4 / JSP 2.0 / JSTL 1.2", "Preservar javax na fase 2; migrar descritores e APIs em gate próprio", "Jakarta EE Web Profile 11 em escopo provided"],
    ["H2", "1.4.200", "Feedback portátil; atualização conforme o gate", "H2 2.4.240 em memória; não substitui Oracle"],
    ["Oracle", "Database 19c", "Banco oficial + schema descartável autorizado", "19c RU 19.3; segredos e driver externos"],
    ["Datasource / JNDI", "java:/jdbc/MigrationDS", "Preservar a fronteira; reprovisionar por runtime", "Mesmo JNDI; pool do servidor; teste de conexão em cada gate"],
  ];
  const table = addTable(slide, values, pos(M, 188, 1196, 454), [145, 190, 392, 469], {
    fontSize: 12.6,
    headerFontSize: 14,
    marginY: 6,
  });
  highlightTableRow(table, 1, 4, C.bluePale, C.blueDark, true);
  highlightTableRow(table, 3, 4, C.amberPale, C.amber, true);
  highlightTableRow(table, 6, 4, C.greenPale, C.green, true);
  addFooter(slide, 8, "Parte 2 · Provas, correções e aprendizados");
  setNotes(
    slide,
    "1min30s",
    "Comprovado: runtime e configuração são parte da entrega; as decisões de plataforma foram versionadas, auditadas e qualificadas por fase.",
    "Destacar Java, WildFly e Oracle. A decisão mais importante foi não colocar seleção de banco ou pool no código da aplicação. O JNDI permaneceu estável enquanto driver, módulo e servidor evoluíram.",
    [RAW, `${BASE}docs/evidence/CP-3K.md`, `${BASE}docs/environment-setup.md`, `${BASE}openspec/specs/wildfly-oracle-runtime/spec.md`, `${BASE}docs/wildfly-java-compatibility.md`],
  );
}

// Slide 9 — library decision table
{
  const slide = newSlide();
  addTitle(slide, "Bibliotecas: preservar contratos, não versões");
  addStatus(slide, "Comprovado no laboratório", "proof", { top: 127 });
  addText(slide, "Atualizar componente mantido · remover API duplicada · substituir biblioteca abandonada · manter APIs e driver do servidor fora do WAR", pos(M, 151, 1160, 30), {
    fontSize: 17,
    color: C.muted,
  });
  const values = [
    ["Componente legado", "Decisão", "Destino / contrato preservado"],
    ["MyBatis 3.4.5", "Atualizar", "3.5.19; mesmos mapeamentos; logImpl=SLF4J"],
    ["Log4j 1.2.14", "Remover do WAR", "SLF4J + JBoss LogManager; categorias, correlação e exceção preservadas"],
    ["Commons FileUpload 1.2.2", "Atualizar e remover", "Multipart nativo com @MultipartConfig e Part; limites e metadados preservados"],
    ["Reflections 0.9.10", "Atualizar e substituir", "ServletContainerInitializer + @HandlesTypes; descoberta de validators preservada"],
    ["Tiles 2.1.4", "Remover", "JSP tag files/includes protegidos; cabeçalho, conteúdo e rodapé preservados"],
    ["XMLBeans 2.3.0", "Atualizar", "5.3.0; fontes regeneradas de forma reproduzível a partir do XSD"],
    ["dom4j 1.6.1", "Atualizar e endurecer", "2.2.0; rejeição de XXE e entidades externas"],
    ["xml-apis 1.3.02", "Remover duplicação", "APIs fornecidas pelo módulo java.xml do JDK"],
    ["Geronimo StAX 1.0", "Remover duplicação", "StAX fornecido pelo módulo java.xml do JDK"],
    ["ojdbc7", "Substituir; fora do WAR", "ojdbc17 23.26.2.0.0 como módulo do WildFly"],
    ["Servlet/JSP/JSTL javax", "Migrar no gate Jakarta", "APIs Jakarta fornecidas pelo WildFly; JSTL compatível"],
    ["TLD / taglib 2.0", "Migrar schema e handler", "TLD 3.0 e tag handler Jakarta"],
  ];
  const table = addTable(slide, values, pos(M, 190, 1196, 460), [235, 280, 681], {
    fontSize: 12,
    headerFontSize: 13.5,
    marginY: 3,
  });
  [2, 3, 4, 5].forEach((row) => highlightTableRow(table, row, 3, row % 2 === 0 ? C.bluePale : "#F3F8FF"));
  [8, 9].forEach((row) => highlightTableRow(table, row, 3, C.panel));
  addFooter(slide, 9, "Parte 2 · Provas, correções e aprendizados");
  setNotes(
    slide,
    "2min",
    "Comprovado: bibliotecas foram atualizadas quando mantidas, removidas quando duplicavam a plataforma e substituídas pelo contrato funcional quando estavam abandonadas ou incompatíveis com Jakarta.",
    "Não ler as doze linhas. Destacar quatro padrões: atualizar componente mantido; remover API já fornecida; substituir biblioteca abandonada pelo contrato; manter driver e APIs do servidor fora do WAR. Usar FileUpload, Reflections e Log4j como exemplos.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/evidence/CP-3K.md`, `${BASE}migration/incompatibility-catalog.md`, `${BASE}openspec/specs/modern-jakarta-webapp/spec.md`],
  );
}

// Slide 10 — durable controls
{
  const slide = newSlide();
  addTitle(slide, "Os controles permanecem; as versões mudam");
  addStatus(slide, "Recomendação para aplicação real", "recommendation");
  addLine(slide, 430, 172, 0, { height: 420, color: C.rule, weight: 1 });
  addText(slide, "5", pos(M, 176, 310, 150), { fontSize: 124, bold: true, color: C.amber, verticalAlignment: "bottom", autoFit: "none" });
  addText(slide, "controles duráveis", pos(M, 326, 330, 44), { fontSize: 30, bold: true, autoFit: "none" });
  addText(slide, "O laboratório não recomenda versões históricas; demonstra uma disciplina reutilizável.", pos(M, 397, 315, 100), {
    fontSize: 20,
    color: C.muted,
  });
  addCallout(slide, "Síntese", "Saber de onde partiu, isolar riscos, provar o executável e manter retorno.", pos(M, 526, 330, 102), "recommendation", { fontSize: 17 });

  const controls = [
    ["01", "Baseline primeiro", "Código, artefato, configuração e comportamento formam a primeira entrega."],
    ["02", "Uma dimensão por vez", "Gates menores preservam diagnóstico e revisão."],
    ["03", "Provar o executável", "Contratos externos e auditoria do WAR valem mais que ‘compilou’."],
    ["04", "Feedback ≠ qualificação", "H2 acelera; Oracle decide a persistência oficial."],
    ["05", "Evidência e rollback", "A aprovação precisa sobreviver a branch, squash e mudança de ambiente."],
  ];
  controls.forEach(([n, head, body], i) => {
    const y = 172 + i * 92;
    addLine(slide, 480, y + 80, 720, { color: C.rule, weight: 1 });
    addText(slide, n, pos(480, y, 52, 44), { fontSize: 15, bold: true, color: C.amber, verticalAlignment: "middle", autoFit: "none" });
    addText(slide, head, pos(545, y, 260, 30), { fontSize: 22, bold: true, autoFit: "none" });
    addText(slide, body, pos(545, y + 36, 655, 42), { fontSize: 16.5, color: C.muted });
  });
  addFooter(slide, 10, "Parte 2 · Provas, correções e aprendizados");
  setNotes(
    slide,
    "1min",
    "Recomendação: versões e quantidade de gates podem mudar; os controles de conhecimento, evidência e retorno não deveriam mudar.",
    "O valor do laboratório não é recomendar versões históricas. É demonstrar uma disciplina: saber de onde se partiu, alterar riscos de forma isolada, provar o artefato real e manter uma opção de retorno.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}openspec/specs/migration-compatibility-lab/spec.md`],
  );
}

// Slide 11 — real application roadmap
{
  const slide = newSlide();
  addTitle(slide, "O piloto começa pelo conhecimento verificável");
  addStatus(slide, "Recomendação para aplicação real", "recommendation");
  addText(slide, "Antes de assumir destino, cronograma ou janela de produção, financiar inventário e baseline.", pos(M, 139, 1080, 30), { fontSize: 20, color: C.muted });
  const steps = [
    ["01", "Enquadrar", "Selecionar piloto e responsáveis de negócio, aplicação, plataforma, DBA e segurança."],
    ["02", "Inventariar", "Mapear artefato, runtime, dependências, configurações, dados, integrações e requisitos operacionais."],
    ["03", "Construir o baseline", "Reproduzir o legado e congelar contratos dos fluxos críticos no banco oficial."],
    ["04", "Desenhar gates", "Separar JVM, servidor, dependências, Jakarta e os riscos específicos encontrados."],
    ["05", "Qualificar e implantar", "Executar trilha portátil, banco oficial, segurança, observabilidade, ensaio de corte e rollback."],
  ];
  steps.forEach(([n, head, body], i) => {
    const y = 184 + i * 76;
    addRect(slide, pos(M, y, 68, 58), { fill: i === 0 ? C.amberPale : C.panel });
    addText(slide, n, pos(M, y, 68, 58), { fontSize: 17, bold: true, color: i === 0 ? C.amber : C.blueDark, alignment: "center", verticalAlignment: "middle", autoFit: "none" });
    addText(slide, head, pos(132, y + 2, 265, 29), { fontSize: 23, bold: true, autoFit: "none" });
    addText(slide, body, pos(420, y + 1, 780, 55), { fontSize: 17.5, color: C.muted, verticalAlignment: "middle" });
    addLine(slide, 132, y + 67, 1068, { color: C.rule, weight: 1 });
  });
  addCallout(slide, "Primeiro compromisso", "Produzir um diagnóstico confiável — não migrar tudo antes de conhecer o ponto de partida.", pos(M, 584, 1196, 72), "recommendation", { fontSize: 18 });
  addFooter(slide, 11, "Parte 3 · Aplicação real e decisão");
  setNotes(
    slide,
    "2min",
    "Recomendação: iniciar por uma aplicação piloto e financiar primeiro conhecimento verificável — inventário e baseline — antes de assumir destino, cronograma ou janela de produção.",
    "O primeiro compromisso não é migrar tudo: é produzir um diagnóstico confiável. Só depois do baseline a equipe consegue propor versões, número de gates, esforço, riscos residuais e alternativas de destino.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/phase2-real-application-migration-runbook.md`, `${BASE}openspec/specs/migration-compatibility-lab/spec.md`],
  );
}

// Slide 12 — gate decision table
{
  const slide = newSlide();
  addTitle(slide, "Cada gate precisa encerrar com uma decisão");
  addStatus(slide, "Recomendação para aplicação real", "recommendation", { top: 127 });
  addText(slide, "Promover apenas com artefato imutável, comportamento aprovado, ambiente identificado, risco residual aceito e retorno ensaiado.", pos(M, 151, 1140, 30), {
    fontSize: 18,
    color: C.muted,
  });
  const values = [
    ["Gate", "Entrega mínima para decisão"],
    ["Inventário", "Escopo, responsáveis, dependências, integrações, EOL/licenças e riscos classificados"],
    ["Baseline", "WAR/checksum, runtime/configuração, contratos e qualificação no banco oficial"],
    ["Ponte de baixo impacto", "JVM e servidor isolados, mesmos contratos e plano explícito de saída"],
    ["Dependências / Jakarta", "Bibliotecas decididas, namespace migrado, WAR auditado e segurança validada"],
    ["JVM final", "Toolchain, bytecode, agentes, desempenho e o mesmo WAR qualificado"],
    ["Corte", "Blue/Green, go/no-go, observabilidade, proteção de dados e rollback cronometrado"],
  ];
  const table = addTable(slide, values, pos(M, 192, 1196, 368), [285, 911], {
    fontSize: 14,
    headerFontSize: 15,
    marginY: 7,
  });
  highlightTableRow(table, 2, 2, C.bluePale, C.blueDark, true);
  highlightTableRow(table, 6, 2, C.amberPale, C.amber, true);
  addCallout(slide, "Limitação", "Carga, cluster, failover, segurança específica, EAR/EJB/JMS, integrações externas e SQL proprietário exigem gates próprios. O laboratório não define prazo, orçamento nem certifica produção.", pos(M, 584, 1196, 72), "limitation", { fontSize: 15.5 });
  addFooter(slide, 12, "Parte 3 · Aplicação real e decisão");
  setNotes(
    slide,
    "1min30s",
    "Recomendação: promover somente quando cada gate tiver artefato imutável, comportamento aprovado, ambiente identificado, risco residual aceito e retorno ensaiado.",
    "Gate é uma decisão, não apenas uma etapa técnica. Se a aplicação real usa recursos ausentes no laboratório, o roteiro ganha novos gates; não se força a aplicação a caber no exemplo.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/phase2-real-application-migration-runbook.md`, `${BASE}docs/evidence/CP-3K.md`],
  );
}

// Slide 13 — decision close (Codex Grid: sparse stacked text flow)
{
  const slide = newSlide();
  addText(slide, "DECISÃO SOLICITADA À LIDERANÇA", pos(M, 40, 540, 24), { fontSize: 15, bold: true, color: C.amber, autoFit: "none" });
  addRect(slide, pos(M, 104, 8, 320), { fill: C.amber });
  addText(slide, "Autorizar enquadramento\ne baseline do piloto", pos(M + 34, 120, 770, 210), {
    fontSize: 62,
    bold: true,
    lineSpacing: 0.96,
    autoFit: "none",
    verticalAlignment: "middle",
  });
  addText(slide, "Aprovar descoberta antes de aprovar a migração completa.", pos(M + 34, 350, 720, 54), {
    fontSize: 25,
    color: C.muted,
  });

  addRect(slide, pos(850, 118, 388, 306), { fill: C.panel });
  const actions = [
    ["01", "Selecionar uma aplicação piloto"],
    ["02", "Nomear patrocinador e responsáveis"],
    ["03", "Autorizar inventário, ambiente isolado e acesso controlado ao banco"],
  ];
  actions.forEach(([n, textValue], i) => {
    const y = 153 + i * 84;
    addText(slide, n, pos(878, y, 46, 28), { fontSize: 14, bold: true, color: C.amber, autoFit: "none" });
    addText(slide, textValue, pos(934, y - 2, 270, 60), { fontSize: 19, bold: true, verticalAlignment: "top" });
    if (i < 2) addLine(slide, 878, y + 65, 326, { color: C.rule, weight: 1 });
  });

  addRect(slide, pos(M, 500, 1196, 134), { fill: C.bluePale });
  addRect(slide, pos(M, 500, 8, 134), { fill: C.blue });
  addText(slide, "PRIMEIRA ENTREGA ESPERADA", pos(M + 28, 524, 380, 22), { fontSize: 14, bold: true, color: C.blueDark, autoFit: "none" });
  addText(slide, "Inventário revisado + baseline reproduzível + mapa de riscos e incompatibilidades + opções de destino e gates", pos(M + 28, 557, 1120, 50), {
    fontSize: 24,
    bold: true,
    verticalAlignment: "middle",
  });
  addText(slide, "Sem compromisso prematuro com corte em produção", pos(M + 28, 642, 600, 20), { fontSize: 14, color: C.muted, autoFit: "none" });
  addText(slide, "13", pos(1160, 674, 78, 24), { fontSize: 12, bold: true, color: C.faint, alignment: "right", autoFit: "shrinkText" });
  setNotes(
    slide,
    "1min30s",
    "Recomendação: autorizar uma etapa limitada de enquadramento e baseline para converter incerteza em evidência antes de decidir pela execução completa da migração.",
    "Fechar com uma decisão objetiva: aprovar descoberta e baseline do piloto, não uma migração cega. Prazo, custo e plano final serão apresentados depois dessa evidência, com alternativas e critérios de go/no-go.",
    [RAW, `${BASE}docs/project-conclusion.md`, `${BASE}docs/phase2-real-application-migration-runbook.md`, `${BASE}docs/checkpoints.md`],
  );
}

async function writeBlob(target, blob) {
  await fs.writeFile(target, new Uint8Array(await blob.arrayBuffer()));
}

async function main() {
  await fs.mkdir(OUT_DIR, { recursive: true });
  for (const [index, slide] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide, format: "png", scale: 1.5 });
    await writeBlob(path.join(OUT_DIR, `${stem}.png`), png);
    const layout = await slide.export({ format: "layout" });
    await fs.writeFile(path.join(OUT_DIR, `${stem}.layout.json`), await layout.text(), "utf8");
    console.log(`rendered ${stem}`);
  }
  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob(path.join(OUT_DIR, "deck-montage.webp"), montage);
  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(FINAL_PPTX);
  const inspect = await presentation.inspect({ kind: "slide,textbox,shape,table,notes", maxChars: 200000 });
  await fs.writeFile(path.join(OUT_DIR, "deck-inspect.ndjson"), inspect.ndjson, "utf8");
  console.log(FINAL_PPTX);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
