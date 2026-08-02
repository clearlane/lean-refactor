#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

block() { jq -n --arg reason "$1" '{decision:"block",reason:$reason,systemMessage:"Lean-Refactor blocked"}'; }
input=$(cat)
if ! transcript=$(jq -er '.transcript_path | select(type == "string" and length > 0)' <<<"$input" 2>/dev/null); then
  echo "Lean-Refactor: invalid hook input; no identifiable session." >&2
  exit 0
fi
[[ -f "$transcript" ]] || {
  echo "Lean-Refactor: transcript missing: $transcript" >&2
  exit 0
}
search_root=$(jq -r '.cwd // .project_dir // empty' <<<"$input" 2>/dev/null || true)
[[ -n "$search_root" && -d "$search_root" ]] || search_root=$(dirname "$transcript")
root=$(resolve_root "$search_root" code-only 2>/dev/null || true)
if git_root=$(resolve_root "$search_root" git 2>/dev/null); then root="$git_root"; fi
[[ -n "$root" ]] || exit 0

matching=""
while IFS= read -r file; do
  sid=$(extract_session_id "$file")
  if grep -Fq "Session ID: $sid" "$transcript" 2>/dev/null; then
    matching="$file"
    break
  fi
done < <(list_state_files "$root")
[[ -n "$matching" ]] || exit 0
if ! validate_state "$matching"; then
  record_corrupt_failure "$matching" "state validation failed"
  block "Corrupt lean-refactor state preserved. Repair state before continuation: $matching"
  exit 0
fi

iteration=$(parse_field "$matching" iteration)
max_iterations=$(parse_field "$matching" max_iterations)
failure_count=$(parse_field "$matching" failure_count)
failure_limit=$(parse_field "$matching" failure_limit)
session_id=$(parse_field "$matching" session_id)
scope=$(parse_field "$matching" scope_path)
audit=$(parse_field "$matching" audit_file)
approval=$(parse_field "$matching" approval_status)
tier=$(parse_field "$matching" tier_floor)
if ((failure_count >= failure_limit)); then
  echo "Lean-Refactor: failure limit reached; evidence preserved: $matching" >&2
  exit 0
fi
if ! last_output=$(jq -rs '[.[] | select(.role == "assistant" or (.message.role? == "assistant"))] | if length == 0 then "" else (last | if .message then .message else . end | .content | map(select(.type == "text") | .text) | join("\n")) end' "$transcript" 2>/dev/null); then
  increment_failure "$matching" "transcript extraction failed" || true
  block "Transcript extraction failed. Evidence preserved: $matching"
  exit 0
fi

marker=""
grep -qx '<lean-refactor-complete>' <<<"$last_output" && marker=complete
grep -qx '<lean-refactor-stuck>' <<<"$last_output" && marker=stuck
if [[ -n "$marker" ]]; then
  if validate_terminal_audit "$matching" "$marker"; then
    ledger=$(parse_field "$matching" boundary_ledger)
    discovery=$(parse_field "$matching" discovery_ledger)
    rm -f "$matching" "$ledger" "$discovery"
    exit 0
  fi
  increment_failure "$matching" "unsupported $marker marker" || true
  block "Marker rejected: audit-backed $marker evidence missing, stale, or invalid. State preserved: $matching"
  exit 0
fi
if ((iteration >= max_iterations)); then
  echo "Lean-Refactor: max iterations reached; state preserved: $matching" >&2
  exit 0
fi
if ! validate_wave "$matching"; then
  increment_failure "$matching" "expected-wave manifest missing, stale, or incomplete" || true
  block "Continuation rejected: persisted expected-wave manifest/status is missing, stale, or incomplete. State preserved: $matching"
  exit 0
fi

next=$((iteration + 1))
update_field "$matching" iteration "$next"
update_field "$matching" failure_count 0
update_field "$matching" last_failure ""
update_field "$matching" phase discovery
reason="Resume canonical lean-refactor workflow from SKILL.md. State: $matching; root: $root; scope: $scope; audit: ${audit:-unset}; iteration: $next/$max_iterations; tier floor: $tier; approval: $approval. Validate persisted approval, expected-wave status, signatures, and evidence before repair."
jq -n --arg reason "$reason" --arg message "Lean-Refactor $next/$max_iterations | $session_id" '{decision:"block",reason:$reason,systemMessage:$message}'
