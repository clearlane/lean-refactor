#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

usage() {
  echo "Usage: conclude-discovery.sh <STATE> <AUDIT> --manifest FILE --current-signature SHA256 [--previous-signature SHA256] --repair-ready-count 0" >&2
}

[[ $# -ge 2 ]] || {
  usage
  exit 64
}
state="$1"
audit="$2"
shift 2
manifest="" current="" previous="" ready=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --manifest) manifest="$2" ;;
    --current-signature) current="$2" ;;
    --previous-signature) previous="$2" ;;
    --repair-ready-count) ready="$2" ;;
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
[[ "$(parse_field "$state" phase)" == audit_ready ]] || {
  echo "Error: discovery conclusion requires completed discovery checkpoints" >&2
  exit 1
}
validate_discovery_ledger "$state" || {
  echo "Error: discovery ledger is invalid" >&2
  exit 1
}
[[ "$audit" == /* && -f "$audit" && "$manifest" == /* && -f "$manifest" ]] || {
  echo "Error: audit and manifest must be absolute existing files" >&2
  exit 64
}
[[ "$current" =~ ^[0-9a-fA-F]{64}$ && "$ready" == 0 ]] || {
  echo "Error: only zero-repair discovery may conclude without approval" >&2
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
trap 'rm -f "$next_state" "$next_audit" "$backup_audit"' EXIT
cp "$state" "$next_state"
cp "$audit" "$next_audit"
{
  printf '\ncompound_iteration: %s\n' "$(parse_field "$state" iteration)"
  printf 'compound_repair_ready_count: 0\n'
  printf 'compound_verification: complete\n'
  printf 'compound_approval_required: no\n'
  printf 'compound_current_signature: %s\n' "$current"
  printf 'compound_previous_signature: %s\n' "$previous"
  printf 'compound_expected_wave_status: complete\n'
  printf 'compound_expected_wave_manifest_hash: %s\n' "$(sha256_file "$manifest")"
} >>"$next_audit"
update_field "$next_state" audit_file "$audit"
update_field "$next_state" current_signature "$current"
update_field "$next_state" previous_signature "$previous"
update_field "$next_state" expected_wave_manifest "$manifest"
update_field "$next_state" expected_wave_manifest_hash "$(sha256_file "$manifest")"
update_field "$next_state" expected_wave_status complete
update_field "$next_state" audit_hash "$(sha256_file "$next_audit")"
COMPOUND_STATE_CANONICAL_PATH="$state" validate_state "$next_state" || {
  echo "Error: discovery conclusion failed validation" >&2
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
trap - EXIT
printf 'Discovery concluded: %s\n' "$state"
