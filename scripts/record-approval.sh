#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
usage() { echo "Usage: record-approval.sh <STATE> <AUDIT> --findings IDS --tier N [--exclude IDS] --baseline-result FILE --reference-inventory FILE --evidence FILE --classification FILE --boundary-diff FILE --state-impact FILE --external-impact FILE --wave-manifest FILE" >&2; }
[[ $# -ge 2 ]] || {
  usage
  exit 64
}
state="$1"
audit="$2"
shift 2
findings="" tier="" exclusions="" baseline="" refs="" evidence="" classification="" boundary="" state_impact="" external_impact="" wave=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --findings) findings="$2" ;; --tier) tier="$2" ;; --exclude) exclusions="$2" ;;
    --baseline-result) baseline="$2" ;; --reference-inventory) refs="$2" ;; --evidence) evidence="$2" ;;
    --classification) classification="$2" ;; --boundary-diff) boundary="$2" ;; --state-impact) state_impact="$2" ;;
    --external-impact) external_impact="$2" ;; --wave-manifest) wave="$2" ;; *)
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
[[ "$audit" == /* && -f "$audit" && -n "$findings" && "$tier" =~ ^[1-4]$ ]] || {
  usage
  exit 64
}
for artifact in "$baseline" "$refs" "$evidence" "$classification" "$boundary" "$state_impact" "$external_impact" "$wave"; do
  [[ "$artifact" == /* && -f "$artifact" ]] || {
    echo "Error: artifact must be absolute existing file: $artifact" >&2
    exit 64
  }
done
next="${state}.tmp.$$"
trap 'rm -f "$next"' EXIT
cp "$state" "$next"
update_field "$next" audit_file "$audit"
update_field "$next" audit_hash "$(sha256_file "$audit")"
update_field "$next" approved_findings "$findings"
update_field "$next" approved_tier "$tier"
update_field "$next" approval_exclusions "$exclusions"
update_field "$next" approval_recorded_at "$(date -u +%Y-%m-%dT%H%M%SZ)"
for binding in "baseline_result:$baseline" "reference_inventory:$refs" "evidence:$evidence" "classification:$classification" "boundary_diff:$boundary" "state_impact:$state_impact" "external_impact:$external_impact"; do
  field=${binding%%:*}
  artifact=${binding#*:}
  update_field "$next" "${field}_artifact" "$artifact"
  update_field "$next" "${field}_hash" "$(sha256_file "$artifact")"
done
update_field "$next" expected_wave_manifest "$wave"
update_field "$next" expected_wave_manifest_hash "$(sha256_file "$wave")"
update_field "$next" expected_wave_status pending
update_field "$next" repository_fingerprint "$(repository_fingerprint "$(parse_field "$next" root_path)" "$(parse_field "$next" mode)" "$audit")"
update_field "$next" approval_status approved
update_field "$next" approval_digest "$(approval_digest_for_state "$next")"
COMPOUND_STATE_CANONICAL_PATH="$state" validate_approval "$next" || {
  echo "Error: approval failed live validation; original state preserved" >&2
  exit 1
}
mv "$next" "$state"
trap - EXIT
printf '%s\n' "$(parse_field "$state" approval_digest)"
