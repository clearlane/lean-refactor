#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
usage() { echo "Usage: record-approval.sh <STATE> <AUDIT> --approver ID [--conditions TEXT] --findings IDS --tier N [--exclude IDS] --baseline-result FILE --reference-inventory FILE --evidence FILE --classification FILE --boundary-diff FILE --state-impact FILE --external-impact FILE --wave-manifest FILE" >&2; }
[[ $# -ge 2 ]] || {
  usage
  exit 64
}
state="$1"
audit="$2"
shift 2
approver="" conditions="" findings="" tier="" exclusions="" baseline="" refs="" evidence="" classification="" boundary="" state_impact="" external_impact="" wave=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --approver) approver="$2" ;; --conditions) conditions="$2" ;; --findings) findings="$2" ;; --tier) tier="$2" ;; --exclude) exclusions="$2" ;;
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
[[ "$(parse_field "$state" phase)" == audit_ready ]] || {
  echo "Error: approval requires completed prior-art, layer-scan, synthesis, and audit checkpoints" >&2
  exit 1
}
validate_discovery_ledger "$state" || {
  echo "Error: discovery ledger is invalid" >&2
  exit 1
}
[[ "$audit" == /* && -f "$audit" && -n "$approver" && "$findings" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ && "$tier" =~ ^[1-4]$ ]] || {
  usage
  exit 64
}
[[ -z "$exclusions" || "$exclusions" =~ ^[A-Za-z0-9._-]+(,[A-Za-z0-9._-]+)*$ ]] || {
  echo "Error: exclusions must be comma-separated stable finding IDs" >&2
  exit 64
}
if ! jq -en --arg findings "$findings" --arg exclusions "$exclusions" '
  ($findings | split(",")) as $approved |
  (if $exclusions == "" then [] else ($exclusions | split(",")) end) as $excluded |
  ($approved | length) == ($approved | unique | length) and
  ($excluded | length) == ($excluded | unique | length) and
  (($approved - $excluded) | length) == ($approved | length)
' >/dev/null; then
  echo "Error: approved and excluded finding IDs must each be unique and disjoint" >&2
  exit 64
fi
for artifact in "$baseline" "$refs" "$evidence" "$classification" "$boundary" "$state_impact" "$external_impact" "$wave"; do
  [[ "$artifact" == /* && -f "$artifact" ]] || {
    echo "Error: artifact must be absolute existing file: $artifact" >&2
    exit 64
  }
done
next="${state}.tmp.$$"
ledger=$(parse_field "$state" boundary_ledger)
next_ledger="${ledger}.tmp.$$"
backup_ledger="${ledger}.bak.$$"
trap 'rm -f "$next" "$next_ledger" "$backup_ledger"' EXIT
cp "$state" "$next"
jq --arg findings "$findings" '
  .boundaries = ($findings | split(",") | map({key: ., value: {
    status: "pending", repair_attempts: 0, verification_failures: 0,
    repair_limit: 2, verification_limit: 2,
    repair_status: "pending", verification_status: "pending", last_result: "",
    last_manifest: "", last_manifest_hash: "", recorded_at: ""
  }}) | from_entries)
' "$ledger" >"$next_ledger"
update_field "$next" boundary_ledger_hash "$(sha256_file "$next_ledger")"
update_field "$next" audit_file "$audit"
update_field "$next" audit_hash "$(sha256_file "$audit")"
update_field "$next" approved_findings "$findings"
update_field "$next" approved_tier "$tier"
update_field "$next" approval_exclusions "$exclusions"
update_field "$next" approval_recorded_at "$(date -u +%Y-%m-%dT%H%M%SZ)"
update_field "$next" approver "$approver"
update_field "$next" approval_conditions "$conditions"
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
update_field "$next" phase approved
update_field "$next" approval_digest "$(approval_digest_for_state "$next")"
cp "$ledger" "$backup_ledger"
mv "$next_ledger" "$ledger"
COMPOUND_STATE_CANONICAL_PATH="$state" validate_approval "$next" || {
  mv "$backup_ledger" "$ledger"
  echo "Error: approval failed live validation; original state preserved" >&2
  exit 1
}
if ! mv "$next" "$state"; then
  mv "$backup_ledger" "$ledger"
  echo "Error: approval state update failed; ledger restored" >&2
  exit 1
fi
rm -f "$backup_ledger"
trap - EXIT
printf '%s\n' "$(parse_field "$state" approval_digest)"
