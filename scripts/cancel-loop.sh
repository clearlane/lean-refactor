#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh disable=SC1091
source "$SCRIPT_DIR/lib.sh"

root_arg="$(pwd)"
target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ -n "${2:-}" ]] || {
        echo "Error: --root requires path" >&2
        exit 1
      }
      root_arg="$2"
      shift 2
      ;;
    --*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      [[ -z "$target" ]] || {
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      }
      target="$1"
      shift
      ;;
  esac
done

scope=$(resolve_directory "$root_arg") || {
  echo "Error: Invalid root/scope: $root_arg" >&2
  exit 1
}
if root=$(resolve_root "$scope" git 2>/dev/null); then :; else root=$(resolve_root "$scope" code-only); fi

found=0
invalid=0
while IFS= read -r file; do
  sid=$(extract_session_id "$file")
  [[ -z "$target" || "$sid" == "$target" ]] || continue
  found=1
  if ! validate_state "$file"; then
    echo "Preserved invalid/corrupt state: $file" >&2
    invalid=1
    continue
  fi
  ledger=$(parse_field "$file" boundary_ledger)
  discovery=$(parse_field "$file" discovery_ledger)
  rm -f "$file" "$ledger" "$discovery"
  echo "Cancelled session: $sid"
done < <(list_state_files "$root")

if ((!found)); then
  if [[ -z "$target" ]]; then
    echo "No active lean-refactor sessions under $root."
  else
    echo "Session not found under $root: $target" >&2
    exit 1
  fi
fi
((invalid == 0)) || exit 2
echo "Source changes preserved."
