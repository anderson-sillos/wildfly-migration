#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$REPOSITORY_ROOT/scripts/smoke-wildfly9-datasource.sh" \
  --server 26 \
  --java 8 \
  "$@"
