#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh disable=SC1091
source "$SCRIPT_DIR/state.sh"

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
  record_corrupt_failure "$matching" "state validation failed" || true
  block "Corrupt lean-refactor state preserved. Repair state before continuation: $matching"
  exit 0
fi

session_id=$(parse_field "$matching" session_id)
if ! last_output=$(jq -rs '[.[] | select(.role == "assistant" or (.message.role? == "assistant"))] | if length == 0 then "" else (last | if .message then .message else . end | .content | map(select(.type == "text") | .text) | join("\n")) end' "$transcript" 2>/dev/null); then
  if acquire_state_lock "$matching"; then
    increment_failure "$matching" "transcript extraction failed" || true
    release_state_lock
  fi
  block "Transcript extraction failed. Evidence preserved: $matching"
  exit 0
fi
last_output_file=$(mktemp)
trap 'rm -f "$last_output_file"' EXIT
printf '%s\n' "$last_output" >"$last_output_file"
result=$("$SCRIPT_DIR/workflow.sh" advance "$matching" --last-output "$last_output_file") || {
  block "Coordinator advance failed. State preserved: $matching"
  exit 0
}
outcome=$(sed -n 's/^outcome=//p' <<<"$result" | tail -n 1)
reason=$(sed -n 's/^reason=//p' <<<"$result" | tail -n 1)
case "$outcome" in
  deny) jq -n --arg reason "$reason" --arg message "Lean-Refactor | $session_id" '{decision:"block",reason:$reason,systemMessage:$message}' ;;
  continue) [[ -z "$reason" ]] || echo "Lean-Refactor: $reason" >&2 ;;
  *) block "Coordinator returned invalid outcome. State preserved: $matching" ;;
esac
