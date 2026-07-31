#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNBOOK="$REPOSITORY_ROOT/docs/legacy-application-runbook.md"
TASKS_FILE="$REPOSITORY_ROOT/.vscode/tasks.json"

required_paths=(
  ".vscode/tasks.json"
  "docs/README.md"
  "docs/codex-handoff.md"
  "docs/cp-3a-java17-runtime.md"
  "docs/cp-3a-dependency-matrix.md"
  "docs/cp-3b-core-dependencies.md"
  "docs/cp-3b-fileupload.md"
  "docs/cp-3b-logging-bridge.md"
  "docs/cp-3b-reflections-bridge.md"
  "docs/evidence/CP-3B.md"
  "docs/evidence/CP-1F.md"
  "docs/environment-setup.md"
  "docs/legacy-application-runbook.md"
  "docs/legacy-baseline-reproduction.md"
  "docs/legacy-upload.md"
  "docs/legacy-xml-import.md"
  "docs/legacy-validation-logging.md"
  "docs/oracle-lab-schema.md"
  "docs/cp-2a-java8-wildfly9.md"
  "docs/wildfly-java-compatibility.md"
  "docs/evidence/CP-2A.md"
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

for marker in \
  'Reflections 0.10.2' \
  '`@Validator`' \
  '`getTypesAnnotatedWith(Validator.class)`' \
  '`Scanners.TypesAnnotated` e `Scanners.SubTypes`' \
  '`org.jboss.modules.ModuleClassLoader`' \
  'Guava 15' \
  'atividade 3.33' \
  '28789b65964b6daf79082179893687140b84493b'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/cp-3b-reflections-bridge.md" \
      "$REPOSITORY_ROOT/migration/steps/CP-3B-reflections-0.10.2.md"; then
    printf 'FALHA: documentação Reflections não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

if ! grep -Fq -- \
    '[Reflections 0.10.2 no CP-3B](cp-3b-reflections-bridge.md)' \
    "$REPOSITORY_ROOT/docs/README.md"; then
  printf 'FALHA: índice não aponta para a decisão Reflections do CP-3B\n' >&2
  exit 1
fi

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
  'legacy-baseline-reproduction.md'
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
  '"label": "CP-2A: iniciar aplicação Java 8 com H2"'
  '"command": "${workspaceFolder}/scripts/smoke-wildfly9-datasource.sh"'
  '"label": "CP-2A: iniciar aplicação Java 8 com Oracle"'
  '"label": "CP-2A: acompanhar log do WildFly 9"'
  '"command": "${workspaceFolder}/scripts/follow-wildfly9-log.sh"'
  '"8"'
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
  'docs/README.md' \
  'docs/legacy-baseline-reproduction.md' \
  'docs/cp-2a-java8-wildfly9.md'; do
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

required_baseline_markers=(
  './scripts/doctor.sh CP-1G --profile ci-h2 --env .env'
  './scripts/doctor.sh CP-1G --profile oracle --env .env'
  './scripts/validate-cp-1g-baseline.sh'
  'migration/01-legacy-baseline'
  '19.3.0.0.0'
  'cleanup-smokes'
  'checkout limpo'
)

for marker in "${required_baseline_markers[@]}"; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/legacy-baseline-reproduction.md"; then
    printf 'FALHA: reprodução do baseline não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

COMPATIBILITY_REFERENCE="$REPOSITORY_ROOT/docs/wildfly-java-compatibility.md"
required_compatibility_markers=(
  '**LTS**: *Long-Term Support* (suporte de longo prazo)'
  '**EOL**: *End of Life* (fim do ciclo de vida)'
  '| Java SE | Distribuição de referência | Situação | Disponibilidade de atualizações |'
  '| WildFly | Estado em 30/07/2026 | EOL formal publicado |'
  '| WildFly | Java 7 | Java 8 | Java 11 | Java 17 | Java 21 | Java 25 |'
  '| 8–9 | Sim | Sim |'
  '| 10–13 | Não | Sim |'
  '**Java EE 8 / Jakarta EE 8** (APIs `javax.*`)'
  '| 41 | Não | Não | Não | Sim | Sim | Rec.⁵ |'
  'Java 25'
  'A indicação do JDK para executar o servidor e a declaração formal de'
  'Atividade 3.1 do laboratório'
  '[evidência do CP-3A](evidence/CP-3A.md)'
  'O projeto WildFly não publica uma matriz formal de EOL'
  'https://www.wildfly.org/news/2026/07/16/WildFly-41-is-released/'
)

for marker in "${required_compatibility_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$COMPATIBILITY_REFERENCE"; then
    printf 'FALHA: referência WildFly/Java não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

if ! grep -Fq -- \
    '[Evolução WildFly × Java SE](wildfly-java-compatibility.md)' \
    "$REPOSITORY_ROOT/docs/README.md"; then
  printf 'FALHA: índice não aponta para a referência WildFly/Java\n' >&2
  exit 1
fi

DEPENDENCY_MATRIX="$REPOSITORY_ROOT/docs/cp-3a-dependency-matrix.md"
required_dependency_matrix_markers=(
  'org.mybatis:mybatis:3.5.19'
  'org.slf4j:log4j-over-slf4j:1.7.36'
  'commons-fileupload:commons-fileupload:1.6.0'
  'org.reflections:reflections:0.10.2'
  'org.apache.xmlbeans:xmlbeans:5.3.0'
  'org.dom4j:dom4j:2.2.0'
  'com.oracle.database.jdbc:ojdbc17:23.26.2.0.0'
  'ServletContainerInitializer'
  'módulo `java.xml`'
  'Nenhuma versão desta página é aplicada antecipadamente ao POM'
)

for marker in "${required_dependency_matrix_markers[@]}"; do
  if ! grep -Fq -- "$marker" "$DEPENDENCY_MATRIX"; then
    printf 'FALHA: matriz de dependências do CP-3A não contém: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

if ! grep -Fq -- \
    '[Matriz de dependências do CP-3A](cp-3a-dependency-matrix.md)' \
    "$REPOSITORY_ROOT/docs/README.md" ||
   ! grep -Fq -- \
    '[matriz de modernização](../cp-3a-dependency-matrix.md)' \
    "$REPOSITORY_ROOT/docs/evidence/CP-3A.md"; then
  printf 'FALHA: índice/evidência não aponta para a matriz do CP-3A\n' >&2
  exit 1
fi

for marker in \
  'Eclipse Temurin OpenJDK | 17.0.20+8' \
  'H2 | 2.4.240' \
  '29b70e427cc1c40cdc376283adbb0cc62853073797bb5fe5761f81fe73d57ce0' \
  'jdbc:h2:mem:migration;MODE=Oracle;DB_CLOSE_DELAY=-1' \
  'atividade 3.14' \
  'migration/02-java8-wildfly26' \
  'qualify-cp-3a-h2.sh' \
  'qualify-cp-3a-oracle.sh'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/cp-3a-java17-runtime.md"; then
    printf 'FALHA: runbook do runtime CP-3A não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

for marker in \
  'MyBatis 3.5.19' \
  'mybatis-3.5.19.jar' \
  'qualify-cp-3b-h2.sh' \
  'qualify-cp-3b-oracle.sh' \
  'portable-ci' \
  'oracle-qualified' \
  '6d94e5fc735575fa2ac644690a2a0635d921199f'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/cp-3b-core-dependencies.md"; then
    printf 'FALHA: documentação CP-3B não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

if ! grep -Fq -- \
    '[Dependências centrais do CP-3B](cp-3b-core-dependencies.md)' \
    "$REPOSITORY_ROOT/docs/README.md"; then
  printf 'FALHA: índice não aponta para o CP-3B\n' >&2
  exit 1
fi

for marker in \
  'Commons FileUpload 1.x transitório' \
  'commons-fileupload:commons-fileupload` de 1.2.2 para 1.6.0' \
  'commons-io:commons-io` de 1.3.2 para 2.19.0' \
  '`javax.servlet`' \
  'arquivo máximo de 512 KiB' \
  'requisição multipart máxima de 576 KiB' \
  'atividade 3.32' \
  'e73f3184917984062d9ce8037d75236631399d99'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/cp-3b-fileupload.md" \
      "$REPOSITORY_ROOT/migration/steps/CP-3B-commons-fileupload-1.6.0.md"; then
    printf 'FALHA: documentação do FileUpload 1.x não contém: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

if ! grep -Fq -- \
    '[FileUpload 1.x no CP-3B](cp-3b-fileupload.md)' \
    "$REPOSITORY_ROOT/docs/README.md"; then
  printf 'FALHA: índice não aponta para a decisão FileUpload do CP-3B\n' >&2
  exit 1
fi

for marker in \
  'd5f8a08242d4cdd18595a97e010954f1ee29f2f3' \
  '94a6c0d81951cb47f591927222b2a070756ba9b9c67ed2925e88946727ae9106' \
  'MyBatis 3.5.19 pode substituir diretamente' \
  '14 contratos HTTP' \
  'logImpl' \
  '6d94e5fc735575fa2ac644690a2a0635d921199f'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/evidence/CP-3B.md"; then
    printf 'FALHA: evidência CP-3B não contém: %s\n' "$marker" >&2
    exit 1
  fi
done

for marker in \
  'log4j-over-slf4j 1.7.36 no WAR' \
  'slf4j-api 1.7.36 fornecida pelo WildFly' \
  'org.apache.log4j' \
  'jboss-deployment-structure.xml' \
  'WFLYLOG0100' \
  'stack trace do MyBatis' \
  'atividade 3.34'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/cp-3b-logging-bridge.md" \
      "$REPOSITORY_ROOT/migration/steps/CP-3B-log4j-over-slf4j.md"; then
    printf 'FALHA: documentação da ponte de logging não contém: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

for marker in \
  'c9a4ee17b3548e57bd3c5cc499051e34eeebcf9c' \
  '4f6eb8c63b1e7abb9d0c89c1020251686240b98d4901ce2150cc85262442d335' \
  'Log4j 1 pode ser retirado' \
  '22 dependências Maven' \
  'o mesmo MDC' \
  '57d6e7630ef42a85b15e16aeb126a5027c67950d' \
  '3.34 removerá'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/evidence/CP-3B.md"; then
    printf 'FALHA: evidência CP-3B de logging não contém: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

for marker in \
  '64b5962e23a7d5dcb740c3a8d50a6ac172c8878f' \
  'b199837b374d44cc84df1dcadbdfdf3ff53351201305c70828b9b2cc602fa3ff' \
  'Commons FileUpload 1.6.0 e Commons IO 2.19.0 podem substituir diretamente' \
  'limite de 512 KiB por' \
  'limite de 576 KiB por' \
  'portable-ci' \
  'oracle-qualified' \
  'atividade 3.32' \
  'e73f3184917984062d9ce8037d75236631399d99'; do
  if ! grep -Fq -- "$marker" \
      "$REPOSITORY_ROOT/docs/evidence/CP-3B.md"; then
    printf 'FALHA: evidência CP-3B de upload não contém: %s\n' \
      "$marker" >&2
    exit 1
  fi
done

help_output="$(
  "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" --help
)"
if [[ "$help_output" != *"--manual"* ||
      "$help_output" != *"--java 7|8"* ||
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
