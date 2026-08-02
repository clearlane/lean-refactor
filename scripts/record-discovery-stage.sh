#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

usage() { echo "Usage: record-discovery-stage.sh <STATE> --stage prior-art|layers|synthesis|audit --artifact FILE" >&2; }
[[ $# -ge 1 ]] || {
  usage
  exit 64
}
state="$1"
shift
stage="" artifact=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --stage) stage="$2" ;;
    --artifact) artifact="$2" ;;
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
acquire_state_lock "$state" || {
  echo "Error: workflow state is busy; retry this transition: $state" >&2
  exit 75
}
trap 'release_state_lock' EXIT
validate_state "$state" || {
  echo "Error: state changed before discovery lock was acquired" >&2
  exit 1
}
[[ "$stage" =~ ^(prior-art|layers|synthesis|audit)$ && "$artifact" == /* && -f "$artifact" ]] || {
  usage
  exit 64
}

case "$stage" in
  prior-art)
    expected='discovery|rediscovery'
    phase=prior_art
    key=prior_art
    ;;
  layers)
    expected=prior_art
    phase=layer_scans
    key=layers
    ;;
  synthesis)
    expected=layer_scans
    phase=synthesis
    key=synthesis
    ;;
  audit)
    expected=synthesis
    phase=audit_ready
    key=audit
    ;;
esac
[[ "$(parse_field "$state" phase)" =~ ^($expected)$ ]] || {
  echo "Error: discovery stage is out of order: $stage" >&2
  exit 1
}

ledger=$(parse_field "$state" discovery_ledger)
iteration=$(parse_field "$state" iteration)
next_ledger="${ledger}.tmp.$$"
next_state="${state}.tmp.$$"
backup_ledger="${ledger}.bak.$$"
trap 'rm -f "$next_ledger" "$next_state" "$backup_ledger"; release_state_lock' EXIT
jq --arg iteration "$iteration" --arg key "$key" --arg artifact "$artifact" \
  --arg artifact_hash "$(sha256_file "$artifact")" --arg recorded_at "$(date -u +%Y-%m-%dT%H%M%SZ)" '
  .iterations[$iteration] = (.iterations[$iteration] // {
    prior_art: {status:"pending",artifact:"",artifact_hash:"",recorded_at:""},
    layers: {status:"pending",artifact:"",artifact_hash:"",recorded_at:""},
    synthesis: {status:"pending",artifact:"",artifact_hash:"",recorded_at:""},
    audit: {status:"pending",artifact:"",artifact_hash:"",recorded_at:""}
  }) |
  .iterations[$iteration][$key] = {status:"completed",artifact:$artifact,artifact_hash:$artifact_hash,recorded_at:$recorded_at}
' "$ledger" >"$next_ledger"
cp "$state" "$next_state"
update_field "$next_state" discovery_ledger_hash "$(sha256_file "$next_ledger")"
update_field "$next_state" phase "$phase"
cp "$ledger" "$backup_ledger"
mv "$next_ledger" "$ledger"
COMPOUND_STATE_CANONICAL_PATH="$state" validate_discovery_ledger "$next_state" || {
  mv "$backup_ledger" "$ledger"
  echo "Error: discovery checkpoint failed validation" >&2
  exit 1
}
if ! mv "$next_state" "$state"; then
  mv "$backup_ledger" "$ledger"
  echo "Error: discovery state update failed; ledger restored" >&2
  exit 1
fi
rm -f "$backup_ledger"
release_state_lock
trap - EXIT
printf 'Discovery stage recorded: %s\n' "$stage"
