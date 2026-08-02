#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: workflow.sh <command> [arguments]

Commands:
  init [SCOPE] [--max-iterations N] [--tier-floor N] [--code-only]
  approve <STATE> <AUDIT> <record-approval options>
  verify-approval <STATE>
  boundary <STATE> <record-boundary-result options>
  finalize <STATE> <AUDIT> <record-wave options>
  conclude-discovery <STATE> <AUDIT> <conclude-discovery options>
  status <STATE>
  cancel [--root PATH] [SESSION_ID]
EOF
}

[[ $# -ge 1 ]] || {
  usage
  exit 64
}
command_name="$1"
shift
case "$command_name" in
  init) exec "$SCRIPT_DIR/setup-loop.sh" "$@" ;;
  approve) exec "$SCRIPT_DIR/record-approval.sh" "$@" ;;
  verify-approval) exec "$SCRIPT_DIR/verify-approval.sh" "$@" ;;
  boundary) exec "$SCRIPT_DIR/record-boundary-result.sh" "$@" ;;
  finalize) exec "$SCRIPT_DIR/record-wave.sh" "$@" ;;
  conclude-discovery) exec "$SCRIPT_DIR/conclude-discovery.sh" "$@" ;;
  status)
    [[ $# -eq 1 ]] || {
      usage
      exit 64
    }
    source "$SCRIPT_DIR/lib.sh"
    validate_state "$1" || {
      echo "Error: invalid state: $1" >&2
      exit 1
    }
    printf 'session_id=%s\nphase=%s\niteration=%s\napproval_status=%s\nstate=%s\nboundary_ledger=%s\n' \
      "$(parse_field "$1" session_id)" "$(parse_field "$1" phase)" \
      "$(parse_field "$1" iteration)" "$(parse_field "$1" approval_status)" \
      "$1" "$(parse_field "$1" boundary_ledger)"
    ;;
  cancel) exec "$SCRIPT_DIR/cancel-loop.sh" "$@" ;;
  *)
    usage
    exit 64
    ;;
esac
