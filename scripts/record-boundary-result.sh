#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

usage() {
  echo "Usage: record-boundary-result.sh <STATE> --boundary ID --kind repair|verification --result completed|retryable|failed|blocked --manifest FILE" >&2
}

[[ $# -ge 1 ]] || {
  usage
  exit 64
}
state="$1"
shift
boundary="" kind="" result="" manifest=""
while [[ $# -gt 0 ]]; do
  [[ $# -ge 2 ]] || {
    usage
    exit 64
  }
  case "$1" in
    --boundary) boundary="$2" ;;
    --kind) kind="$2" ;;
    --result) result="$2" ;;
    --manifest) manifest="$2" ;;
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
[[ "$boundary" =~ ^[A-Za-z0-9._-]+$ && "$kind" =~ ^(repair|verification)$ && "$result" =~ ^(completed|retryable|failed|blocked)$ ]] || {
  usage
  exit 64
}
[[ "$manifest" == /* && -f "$manifest" ]] || {
  echo "Error: manifest must be an absolute existing file" >&2
  exit 64
}

ledger=$(parse_field "$state" boundary_ledger)
next_ledger="${ledger}.tmp.$$"
next_state="${state}.tmp.$$"
backup_ledger="${ledger}.bak.$$"
trap 'rm -f "$next_ledger" "$next_state" "$backup_ledger"' EXIT

repair_increment=0
verification_increment=0
if [[ "$kind" == repair && "$result" =~ ^(retryable|failed)$ ]]; then repair_increment=1; fi
if [[ "$kind" == verification && "$result" =~ ^(retryable|failed)$ ]]; then verification_increment=1; fi

jq --arg id "$boundary" --arg kind "$kind" --arg result "$result" \
  --arg manifest "$manifest" --arg manifest_hash "$(sha256_file "$manifest")" \
  --arg recorded_at "$(date -u +%Y-%m-%dT%H%M%SZ)" \
  --argjson repair_increment "$repair_increment" --argjson verification_increment "$verification_increment" '
  .boundaries[$id] = ((.boundaries[$id] // {
    status: "pending", repair_attempts: 0, verification_failures: 0,
    repair_limit: 2, verification_limit: 2,
    repair_status: "pending", verification_status: "pending", last_result: "",
    last_manifest: "", last_manifest_hash: "", recorded_at: ""
  }) |
    .repair_attempts += $repair_increment |
    .verification_failures += $verification_increment |
    .last_result = ($kind + ":" + $result) |
    .last_manifest = $manifest |
    .last_manifest_hash = $manifest_hash |
    .recorded_at = $recorded_at |
    (if $kind == "repair" then
      .repair_status = (if $result == "completed" then "completed"
        elif $result == "blocked" or .repair_attempts >= .repair_limit then "blocked"
        else "pending" end)
    else
      .verification_status = (if $result == "completed" then "completed"
        elif $result == "blocked" or .verification_failures >= .verification_limit then "blocked"
        else "pending" end)
    end) |
    .status = (if .repair_status == "blocked" or .verification_status == "blocked" then "blocked"
      elif .repair_status == "completed" and .verification_status == "completed" then "completed"
      else "pending" end)
  )' "$ledger" >"$next_ledger"

cp "$state" "$next_state"
update_field "$next_state" boundary_ledger_hash "$(sha256_file "$next_ledger")"
cp "$ledger" "$backup_ledger"
mv "$next_ledger" "$ledger"
COMPOUND_STATE_CANONICAL_PATH="$state" validate_boundary_ledger "$next_state" || {
  mv "$backup_ledger" "$ledger"
  echo "Error: boundary result failed validation" >&2
  exit 1
}
if ! mv "$next_state" "$state"; then
  mv "$backup_ledger" "$ledger"
  echo "Error: boundary state update failed; ledger restored" >&2
  exit 1
fi
rm -f "$backup_ledger"
trap - EXIT
jq -c --arg id "$boundary" '.boundaries[$id]' "$ledger"
