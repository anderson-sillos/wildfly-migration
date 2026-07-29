#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$REPOSITORY_ROOT/docs/legacy-application-runbook.md"
TASKS_FILE="$REPOSITORY_ROOT/.vscode/tasks.json"

required_paths=(
  ".vscode/tasks.json"
  "docs/README.md"
  "docs/codex-handoff.md"
  "docs/evidence/CP-1F.md"
  "docs/environment-setup.md"
  "docs/legacy-application-runbook.md"
  "docs/legacy-upload.md"
  "docs/legacy-xml-import.md"
  "docs/legacy-validation-logging.md"
  "docs/oracle-lab-schema.md"
  "runtime/legacy/README.md"
  "runtime/legacy/profiles/README.md"
  "scripts/follow-wildfly9-log.sh"
)

for path in "${required_paths[@]}"; do
  if [[ ! -f "$REPOSITORY_ROOT/$path" ]]; then
    printf 'FALHA: documentação obrigatória ausente: %s\n' "$path" >&2
    exit 1
  fi
done

required_runbook_markers=(
  './scripts/doctor.sh CP-1E --profile ci-h2 --env .env'
  './scripts/doctor.sh CP-1E --profile oracle --env .env'
  './scripts/build-cp-1d.sh --profile ci-h2 --env .env'
  './scripts/build-cp-1d.sh --profile oracle --env .env'
  './scripts/oracle-lab-schema.sh inspect --env .env'
  'O perfil não é armazenado no `.env`'
  '--war app/target/wildfly-migration.war'
  '--manual'
  'http://127.0.0.1:18080/wildfly-migration/pedidos'
  'http://127.0.0.1:18080/wildfly-migration/health'
  'Log bruto do WildFly:'
  'tail -f --'
  'o `server.log` é bruto'
  'Ctrl+C'
  'Legado: iniciar aplicação H2 para teste manual'
  'Legado: iniciar aplicação Oracle para teste manual'
  'Legado: acompanhar log do WildFly'
  'LAB-SMOKE-*'
  'Upload legado do CP-1F'
  'Importação XML'
  'DROP USER ... CASCADE'
)

if ! grep -Fq -- '[Codex handoff](codex-handoff.md)' \
    "$REPOSITORY_ROOT/docs/README.md"; then
  printf 'FALHA: índice da documentação não referencia o Codex handoff\n' >&2
  exit 1
fi

for marker in "${required_runbook_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$RUNBOOK"; then
    printf 'FALHA: runbook não contém o contrato operacional: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

required_task_markers=(
  '"label": "Legado: iniciar aplicação H2 para teste manual"'
  '"command": "${workspaceFolder}/scripts/smoke-wildfly9-datasource.sh"'
  '"label": "Legado: iniciar aplicação Oracle para teste manual"'
  '"label": "Legado: acompanhar log do WildFly"'
  '"command": "${workspaceFolder}/scripts/follow-wildfly9-log.sh"'
)

for marker in "${required_task_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$TASKS_FILE"; then
    printf 'FALHA: tasks do VS Code não contêm o contrato operacional: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

for reference in \
  'docs/legacy-application-runbook.md' \
  'docs/README.md'; do
  if ! grep -Fq "$reference" "$REPOSITORY_ROOT/README.md"; then
    printf 'FALHA: README principal não aponta para %s\n' "$reference" >&2
    exit 1
  fi
done

if ! grep -Fq 'legacy-application-runbook.md' \
    "$REPOSITORY_ROOT/docs/environment-setup.md" ||
   ! grep -Fq 'legacy-application-runbook.md' \
    "$REPOSITORY_ROOT/runtime/legacy/README.md" ||
   ! grep -Fq 'legacy-application-runbook.md' \
    "$REPOSITORY_ROOT/runtime/legacy/profiles/README.md"; then
  printf 'FALHA: documentos especializados não apontam para o runbook\n' >&2
  exit 1
fi

help_output="$(
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" --help
)"
if [[ "$help_output" != *"--manual"* ||
      "$help_output" != *"mantém a aplicação ativa"* ||
      "$help_output" != *"caminho do log bruto"* ]]; then
  printf 'FALHA: ajuda do runtime não documenta o modo manual\n' >&2
  exit 1
fi

broken_links=0
while IFS= read -r markdown; do
  while IFS= read -r token; do
    target="${token#](}"
    target="${target%)}"
    target="${target%%#*}"
    case "$target" in
      ""|http://*|https://*|mailto:*)
        continue
        ;;
    esac

    if [[ ! -e "$(dirname "$markdown")/$target" ]]; then
      printf 'FALHA: link local inválido em %s: %s\n' \
        "${markdown#"$REPOSITORY_ROOT/"}" "$target" >&2
      broken_links=$((broken_links + 1))
    fi
  done < <(grep -Eo '\]\([^ )]+\)' "$markdown" || true)
done < <(
  find "$REPOSITORY_ROOT" \
    -path "$REPOSITORY_ROOT/.git" -prune -o \
    -path "$REPOSITORY_ROOT/.codex" -prune -o \
    -path "$REPOSITORY_ROOT/.agents" -prune -o \
    -path "$REPOSITORY_ROOT/app/target" -prune -o \
    -type f -name '*.md' -print
)

if (( broken_links > 0 )); then
  exit 1
fi

printf 'OK: índice e runbook legado contêm o ciclo manual consolidado\n'
