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
[[ "$(parse_field "$state" phase)" =~ ^(approved|repair|verification)$ ]] || {
  echo "Error: boundary results require approved workflow state" >&2
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
jq -e --arg boundary "$boundary" --arg result "$result" '
  .schema_version == 1 and
  .boundary_id == $boundary and
  .result == $result and
  (.attempt | type == "number" and . >= 1 and floor == .) and
  (.branch_worktree | type == "string" and length > 0) and
  (.base_fingerprint | type == "string" and length > 0) and
  (.diff_fingerprint | type == "string" and length > 0) and
  (.allowed_paths | type == "array" and length > 0 and
    length == (unique | length) and all(.[];
      type == "string" and length > 0 and
      (startswith("/") | not) and
      (split("/") | all(.[]; length > 0 and . != "." and . != "..")))) and
  (.changed_paths | type == "array" and length == (unique | length) and all(.[];
    type == "string" and length > 0 and
    (startswith("/") | not) and
    (split("/") | all(.[]; length > 0 and . != "." and . != "..")))) and
  ((.changed_paths - .allowed_paths) | length == 0) and
  (.commands | type == "array" and all(.[];
    (.command | type == "string" and length > 0) and
    (.exit_code | type == "number" and floor == .) and
    (.evidence | type == "string" and length > 0))) and
  (.evidence_artifacts | type == "array" and all(.[];
    (.path | type == "string" and startswith("/")) and
    (.sha256 | type == "string" and test("^[0-9a-fA-F]{64}$")))) and
  (.blocker | type == "string") and
  (.stale_dependents | type == "array" and length == (unique | length) and
    all(.[]; type == "string" and test("^[A-Za-z0-9._-]+$"))) and
  (if $result == "completed" then
    (.commands | length > 0 and all(.[]; .exit_code == 0)) and .blocker == ""
   else
    (.evidence_artifacts | length > 0) and (.blocker | length > 0)
   end)
' "$manifest" >/dev/null || {
  echo "Error: boundary manifest does not satisfy the required JSON contract" >&2
  exit 64
}
while IFS=$'\t' read -r evidence_path evidence_hash; do
  [[ -f "$evidence_path" && "$(sha256_file "$evidence_path")" == "$(printf '%s' "$evidence_hash" | tr '[:upper:]' '[:lower:]')" ]] || {
    echo "Error: boundary evidence artifact is missing or stale: $evidence_path" >&2
    exit 1
  }
done < <(jq -r '.evidence_artifacts[] | [.path, (.sha256 | ascii_downcase)] | @tsv' "$manifest")

ledger=$(parse_field "$state" boundary_ledger)
jq -e --arg id "$boundary" '.boundaries | has($id)' "$ledger" >/dev/null || {
  echo "Error: boundary is not part of approved findings: $boundary" >&2
  exit 1
}
existing_status=$(jq -r --arg id "$boundary" '.boundaries[$id].status' "$ledger")
[[ "$existing_status" != blocked ]] || {
  echo "Error: boundary failure budget is exhausted: $boundary" >&2
  exit 1
}
stage_status=$(jq -r --arg id "$boundary" --arg kind "$kind" '.boundaries[$id][($kind + "_status")]' "$ledger")
[[ "$stage_status" != completed ]] || {
  echo "Error: boundary stage is already completed: $boundary/$kind" >&2
  exit 1
}
if [[ "$kind" == verification ]]; then
  [[ "$(jq -r --arg id "$boundary" '.boundaries[$id].repair_status' "$ledger")" == completed ]] || {
    echo "Error: verification requires completed repair: $boundary" >&2
    exit 1
  }
fi
if [[ "$kind" == repair ]]; then
  expected_attempt=$(($(jq -r --arg id "$boundary" '.boundaries[$id].repair_attempts' "$ledger") + 1))
else
  expected_attempt=$(($(jq -r --arg id "$boundary" '.boundaries[$id].verification_failures' "$ledger") + 1))
fi
[[ "$(jq -r '.attempt' "$manifest")" == "$expected_attempt" ]] || {
  echo "Error: $kind manifest attempt does not match durable counter; expected $expected_attempt" >&2
  exit 1
}
next_ledger="${ledger}.tmp.$$"
next_state="${state}.tmp.$$"
backup_ledger="${ledger}.bak.$$"
trap 'rm -f "$next_ledger" "$next_state" "$backup_ledger"' EXIT

repair_increment=0
verification_increment=0
if [[ "$kind" == repair ]]; then repair_increment=1; fi
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
if [[ "$kind" == repair ]]; then update_field "$next_state" phase repair; else update_field "$next_state" phase verification; fi
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
