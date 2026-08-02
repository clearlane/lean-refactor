#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

usage() { echo "Usage: advance-loop.sh <STATE> --last-output FILE" >&2; }
[[ $# -eq 3 && "$2" == --last-output ]] || {
  usage
  exit 64
}
state="$1"
last_output_file="$3"
[[ -f "$last_output_file" ]] || {
  echo "Error: last output file missing" >&2
  exit 64
}
validate_state "$state" || {
  echo "Error: invalid state: $state" >&2
  exit 1
}

iteration=$(parse_field "$state" iteration)
max_iterations=$(parse_field "$state" max_iterations)
failure_count=$(parse_field "$state" failure_count)
failure_limit=$(parse_field "$state" failure_limit)
marker=""
grep -qx '<lean-refactor-complete>' "$last_output_file" && marker=complete
grep -qx '<lean-refactor-stuck>' "$last_output_file" && marker=stuck

if [[ -n "$marker" ]]; then
  if validate_terminal_audit "$state" "$marker"; then
    ledger=$(parse_field "$state" boundary_ledger)
    discovery=$(parse_field "$state" discovery_ledger)
    rm -f "$state" "$ledger" "$discovery"
    printf 'outcome=continue\nterminal=%s\n' "$marker"
    exit 0
  fi
  increment_failure "$state" "unsupported $marker marker" || true
  printf 'outcome=deny\nreason=Marker rejected: audit-backed %s evidence missing, stale, or invalid. State preserved: %s\n' "$marker" "$state"
  exit 0
fi

if ((failure_count >= failure_limit)); then
  printf 'outcome=continue\nreason=Failure limit reached; evidence preserved: %s\n' "$state"
  exit 0
fi
if ((iteration >= max_iterations)); then
  printf 'outcome=continue\nreason=Maximum iterations reached; state preserved: %s\n' "$state"
  exit 0
fi
if ! validate_wave "$state"; then
  increment_failure "$state" "expected-wave manifest missing, stale, or incomplete" || true
  printf 'outcome=deny\nreason=Continuation rejected: persisted expected-wave manifest/status is missing, stale, or incomplete. State preserved: %s\n' "$state"
  exit 0
fi

next=$((iteration + 1))
update_fields "$state" iteration "$next" failure_count 0 last_failure "" phase discovery
printf 'outcome=deny\nreason=Resume canonical lean-refactor workflow from SKILL.md. State: %s; root: %s; scope: %s; audit: %s; iteration: %s/%s; tier floor: %s; approval: %s. Validate persisted checkpoints and begin discovery.\n' \
  "$state" "$(parse_field "$state" root_path)" "$(parse_field "$state" scope_path)" \
  "$(parse_field "$state" audit_file)" "$next" "$max_iterations" \
  "$(parse_field "$state" tier_floor)" "$(parse_field "$state" approval_status)"
