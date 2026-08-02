#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=state.sh disable=SC1091
source "$SCRIPT_DIR/state.sh"

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required on PATH." >&2
  exit 1
}

scope=""
max_iterations=10
tier_floor=2
mode="git"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)
      [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || {
        echo "Error: --max-iterations requires positive integer" >&2
        exit 1
      }
      max_iterations="$2"
      shift 2
      ;;
    --tier-floor)
      [[ "${2:-}" =~ ^[1-4]$ ]] || {
        echo "Error: --tier-floor must be 1, 2, 3, or 4" >&2
        exit 1
      }
      tier_floor="$2"
      shift 2
      ;;
    --code-only)
      mode="code-only"
      shift
      ;;
    --*)
      echo "Error: Unexpected option: $1" >&2
      exit 1
      ;;
    *)
      [[ -z "$scope" ]] || {
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      }
      scope="$1"
      shift
      ;;
  esac
done

scope=${scope:-"$(pwd)"}
scope=$(resolve_directory "$scope") || {
  echo "Error: Scope path is not directory: $scope" >&2
  exit 1
}
if ! root=$(resolve_root "$scope" "$mode"); then
  echo "Error: Scope is not in Git repository. Rerun with --code-only to explicitly disable Git/worktree operations." >&2
  exit 1
fi

baseline="code-only"
if [[ "$mode" == "git" ]]; then
  dirty=$(git -C "$root" status --porcelain --untracked-files=normal)
  if [[ -n "$dirty" ]]; then
    echo "Error: Git working tree is dirty; no state or directories created." >&2
    echo "Choose one:" >&2
    echo "  1. Commit pending work through canonical workflow, then rerun." >&2
    echo "  2. Run setup against another clean worktree." >&2
    echo "  3. Rerun with --code-only only when Git isolation/commits are intentionally disabled." >&2
    printf '%s\n' "$dirty" >&2
    exit 2
  fi
  baseline=$(git -C "$root" rev-parse HEAD)
fi

session_suffix=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' | cut -c1-8 || true)
[[ -n "$session_suffix" ]] || session_suffix="$(date +%s)-$$"
session_id="$(date +%Y%m%d%H%M%S)-$session_suffix"
valid_session_id "$session_id" || {
  echo "Error: Failed to create safe session ID" >&2
  exit 1
}

dir=$(state_dir "$root")
file=$(state_path "$root" "$session_id")
mkdir -p "$dir"
write_state "$file" "$session_id" "$max_iterations" "$tier_floor" "$mode" "$root" "$scope" "$baseline"
validate_state "$file" || {
  echo "Error: Written state failed validation: $file" >&2
  exit 1
}

printf 'Session ID: %s\nRoot: %s\nScope: %s\nMode: %s\nState: %s\n' "$session_id" "$root" "$scope" "$mode" "$file"
