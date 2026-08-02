#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

[[ $# -eq 1 ]] || {
  echo "Usage: verify-approval.sh <STATE>" >&2
  exit 64
}

state="$1"
validate_approval "$state" || {
  echo "Error: approval is absent, stale, or invalid" >&2
  exit 1
}

printf 'approval_digest=%s\n' "$(parse_field "$state" approval_digest)"
printf 'approver=%s\n' "$(parse_field "$state" approver)"
printf 'approval_conditions=%s\n' "$(parse_field "$state" approval_conditions)"
printf 'approved_findings=%s\n' "$(parse_field "$state" approved_findings)"
printf 'approved_tier=%s\n' "$(parse_field "$state" approved_tier)"
printf 'approval_exclusions=%s\n' "$(parse_field "$state" approval_exclusions)"
printf 'repository_fingerprint=%s\n' "$(parse_field "$state" repository_fingerprint)"
