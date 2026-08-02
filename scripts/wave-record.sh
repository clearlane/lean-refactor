#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/state.sh"
usage() { echo "Usage: wave-record.sh <STATE> <AUDIT> --manifest FILE --current-signature SHA256 [--previous-signature SHA256] --repair-ready-count N --approval-required yes|no" >&2; }
[[ $# -ge 2 ]] || {
  usage
  exit 64
}
state="$1"
audit="$2"
shift 2
manifest="" current="" previous="" ready="" approval_required=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --manifest) manifest="$2" ;; --current-signature) current="$2" ;; --previous-signature) previous="$2" ;;
    --repair-ready-count) ready="$2" ;; --approval-required) approval_required="$2" ;; *)
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
acquire_state_lock "$state" || {
  echo "Error: workflow state is busy; retry this transition: $state" >&2
  exit 75
}
trap 'release_state_lock' EXIT
validate_state "$state" || {
  echo "Error: state changed before finalization lock was acquired" >&2
  exit 1
}
[[ "$audit" == "$(parse_field "$state" audit_file)" && -f "$audit" ]] || {
  echo "Error: audit does not match state" >&2
  exit 1
}
[[ "$manifest" == /* && -f "$manifest" && "$current" =~ ^[0-9a-fA-F]{64}$ && "$ready" =~ ^[0-9]+$ && "$approval_required" =~ ^(yes|no)$ ]] || {
  usage
  exit 64
}
[[ -z "$previous" || "$previous" =~ ^[0-9a-fA-F]{64}$ ]] || {
  usage
  exit 64
}
current=$(printf '%s' "$current" | tr '[:upper:]' '[:lower:]')
previous=$(printf '%s' "$previous" | tr '[:upper:]' '[:lower:]')
[[ "$(parse_field "$state" expected_wave_status)" == pending ]] || {
  echo "Error: wave is not pending" >&2
  exit 1
}
[[ "$(sha256_file "$manifest")" == "$(parse_field "$state" expected_wave_manifest_hash)" ]] || {
  echo "Error: manifest changed since approval" >&2
  exit 1
}
validate_approval_envelope "$state" || {
  echo "Error: approval envelope is invalid" >&2
  exit 1
}
[[ "$(parse_field "$state" phase)" =~ ^(approved|repair|verification)$ ]] || {
  echo "Error: wave finalization is not valid in current phase" >&2
  exit 1
}
boundary_ledger_ready "$state" || {
  echo "Error: every approved boundary must complete repair and verification" >&2
  exit 1
}
next_state="${state}.tmp.$$"
next_audit="${audit}.tmp.$$"
backup_audit="${audit}.bak.$$"
trap 'rm -f "$next_state" "$next_audit" "$backup_audit"; release_state_lock' EXIT
cp "$state" "$next_state"
cp "$audit" "$next_audit"
{
  printf '\nlean_iteration: %s\n' "$(parse_field "$state" iteration)"
  printf 'lean_repair_ready_count: %s\n' "$ready"
  printf 'lean_verification: complete\n'
  printf 'lean_approval_required: %s\n' "$approval_required"
  printf 'lean_current_signature: %s\n' "$current"
  printf 'lean_previous_signature: %s\n' "$previous"
  printf 'lean_expected_wave_status: complete\n'
  printf 'lean_expected_wave_manifest_hash: %s\n' "$(sha256_file "$manifest")"
} >>"$next_audit"
update_field "$next_state" current_signature "$current"
update_field "$next_state" previous_signature "$previous"
update_field "$next_state" expected_wave_status complete
update_field "$next_state" phase rediscovery
update_field "$next_state" audit_hash "$(sha256_file "$next_audit")"
LEAN_STATE_CANONICAL_PATH="$state" validate_state "$next_state" || {
  echo "Error: finalized state failed validation" >&2
  exit 1
}
cp "$audit" "$backup_audit"
mv "$next_audit" "$audit"
if ! mv "$next_state" "$state"; then
  mv "$backup_audit" "$audit"
  echo "Error: state finalization failed; audit restored" >&2
  exit 1
fi
rm -f "$backup_audit"
release_state_lock
trap - EXIT
printf 'Wave finalized: %s\n' "$state"
