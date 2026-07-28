#!/usr/bin/env bash
# Thin wrapper — prefer running from the monorepo root:
#   cd .. && ./run.sh
# or:
#   ../run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/run.sh" "$@"
