#!/bin/bash
# review-report.sh — terminal transition for a depth=review run.
#
# A review run stops at findings: it renders the audit as the deliverable and
# completes without manufacturing an approval. Repair-bound transitions stay
# unreachable, so a review can never mutate the repository it examined.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh disable=SC1091
source "$SCRIPT_DIR/state.sh"

usage() {
  echo "Usage: review-report.sh <STATE> <AUDIT> --manifest FILE --current-signature SHA256 [--previous-signature SHA256] --finding-count N" >&2
}

[[ $# -ge 2 ]] || {
  usage
  exit 64
}
state="$1"
audit="$2"
shift 2
manifest="" current="" previous="" findings=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --manifest) manifest="$2" ;;
    --current-signature) current="$2" ;;
    --previous-signature) previous="$2" ;;
    --finding-count) findings="$2" ;;
    *)
      usage
      exit 64
      ;;
  esac
  shift 2
done

validate_state "$state" || {
  echo "Error: invalid state: $state" >&2
  exit 1
}
[[ "$(parse_field "$state" depth)" == review ]] || {
  echo "Error: review reporting requires a depth=review run; a refactor run concludes through approval and repair." >&2
  exit 1
}
acquire_state_lock "$state" || {
  echo "Error: workflow state is busy; retry this transition: $state" >&2
  exit 75
}
trap 'release_state_lock' EXIT
validate_state "$state" || {
  echo "Error: state changed before report lock was acquired" >&2
  exit 1
}
[[ "$(parse_field "$state" phase)" == audit_ready ]] || {
  echo "Error: review reporting requires completed discovery checkpoints" >&2
  exit 1
}
validate_discovery_ledger "$state" || {
  echo "Error: discovery ledger is invalid" >&2
  exit 1
}
validate_discovery_audit "$state" "$audit" || {
  echo "Error: report audit must match the current discovery audit checkpoint" >&2
  exit 1
}
[[ "$audit" == /* && -f "$audit" && "$manifest" == /* && -f "$manifest" ]] || {
  echo "Error: audit and manifest must be absolute existing files" >&2
  exit 64
}
[[ "$current" =~ ^[0-9a-fA-F]{64}$ ]] || {
  usage
  exit 64
}
# A review publishes whatever it found, including nothing. The count is
# recorded rather than gated so an empty review stays a valid outcome.
[[ "$findings" =~ ^[0-9]+$ ]] || {
  echo "Error: --finding-count must be a non-negative integer" >&2
  exit 64
}
[[ -z "$previous" || "$previous" =~ ^[0-9a-fA-F]{64}$ ]] || {
  usage
  exit 64
}
current=$(printf '%s' "$current" | tr '[:upper:]' '[:lower:]')
previous=$(printf '%s' "$previous" | tr '[:upper:]' '[:lower:]')

next_state="${state}.tmp.$$"
next_audit="${audit}.tmp.$$"
backup_audit="${audit}.bak.$$"
trap 'rm -f "$next_state" "$next_audit" "$backup_audit"; release_state_lock' EXIT
cp "$state" "$next_state"
cp "$audit" "$next_audit"
{
  printf '\nlean_iteration: %s\n' "$(parse_field "$state" iteration)"
  printf 'lean_depth: review\n'
  printf 'lean_finding_count: %s\n' "$findings"
  printf 'lean_verification: complete\n'
  printf 'lean_approval_required: no\n'
  printf 'lean_current_signature: %s\n' "$current"
  printf 'lean_previous_signature: %s\n' "$previous"
  printf 'lean_expected_wave_status: complete\n'
  printf 'lean_expected_wave_manifest_hash: %s\n' "$(sha256_file "$manifest")"
} >>"$next_audit"
update_field "$next_state" phase reported
update_field "$next_state" audit_file "$audit"
update_field "$next_state" current_signature "$current"
update_field "$next_state" previous_signature "$previous"
update_field "$next_state" expected_wave_manifest "$manifest"
update_field "$next_state" expected_wave_manifest_hash "$(sha256_file "$manifest")"
update_field "$next_state" expected_wave_status complete
update_field "$next_state" audit_hash "$(sha256_file "$next_audit")"
LEAN_STATE_CANONICAL_PATH="$state" validate_state "$next_state" || {
  echo "Error: review report failed validation" >&2
  exit 1
}
cp "$audit" "$backup_audit"
mv "$next_audit" "$audit"
if ! mv "$next_state" "$state"; then
  mv "$backup_audit" "$audit"
  echo "Error: state update failed; audit restored" >&2
  exit 1
fi
rm -f "$backup_audit"
release_state_lock
trap - EXIT
printf 'Review reported: %s findings; %s\n' "$findings" "$state"
