#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

QUALIFICATION_CHECKPOINT=CP-3D \
  "$REPOSITORY_ROOT/scripts/qualify-cp-3b-h2.sh" "$@"
