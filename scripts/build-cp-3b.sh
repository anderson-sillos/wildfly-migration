#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$REPOSITORY_ROOT/scripts/build-cp-1d.sh" \
  --java 17 --maven 3.9.16 "$@"
