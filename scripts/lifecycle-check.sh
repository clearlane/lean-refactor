#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v bats >/dev/null 2>&1; then
  exec bats "$SCRIPT_DIR/../tests"
fi

echo "Warning: bats is unavailable; running the portable lifecycle smoke check." >&2
exec "$SCRIPT_DIR/lifecycle-smoke.sh"
