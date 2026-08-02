#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
Usage: workflow.sh <command> [arguments]

Commands:
  init [SCOPE] [--max-iterations N] [--tier-floor N] [--code-only]
  discovery <STATE> --stage prior-art|layers|synthesis|audit --artifact FILE
  approve <STATE> <AUDIT> <record-approval options>
  verify-approval <STATE>
  boundary <STATE> <record-boundary-result options>
  finalize <STATE> <AUDIT> <record-wave options>
  conclude-discovery <STATE> <AUDIT> <conclude-discovery options>
  advance <STATE> --last-output FILE
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
  init) exec "$SCRIPT_DIR/loop-setup.sh" "$@" ;;
  discovery) exec "$SCRIPT_DIR/discovery-record.sh" "$@" ;;
  approve) exec "$SCRIPT_DIR/approval-record.sh" "$@" ;;
  verify-approval) exec "$SCRIPT_DIR/approval-verify.sh" "$@" ;;
  boundary) exec "$SCRIPT_DIR/boundary-record.sh" "$@" ;;
  finalize) exec "$SCRIPT_DIR/wave-record.sh" "$@" ;;
  conclude-discovery) exec "$SCRIPT_DIR/discovery-conclude.sh" "$@" ;;
  advance) exec "$SCRIPT_DIR/loop-advance.sh" "$@" ;;
  status)
    [[ $# -eq 1 ]] || {
      usage
      exit 64
    }
    source "$SCRIPT_DIR/state.sh"
    validate_state "$1" || {
      echo "Error: invalid state: $1" >&2
      exit 1
    }
    printf 'session_id=%s\nphase=%s\niteration=%s\napproval_status=%s\nstate=%s\nboundary_ledger=%s\n' \
      "$(parse_field "$1" session_id)" "$(parse_field "$1" phase)" \
      "$(parse_field "$1" iteration)" "$(parse_field "$1" approval_status)" \
      "$1" "$(parse_field "$1" boundary_ledger)"
    ;;
  cancel) exec "$SCRIPT_DIR/loop-cancel.sh" "$@" ;;
  *)
    usage
    exit 64
    ;;
esac
