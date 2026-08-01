#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../references/audit-file-template.md"

usage() { echo "Usage: file-findings.sh <scope-slug> [--root <repo-root>] [--read-only]" >&2; }
scope="${1:-}"
[[ -n "$scope" ]] || {
  usage
  exit 1
}
shift
scope="${scope//[^A-Za-z0-9._-]/-}"
root="$(pwd)"
read_only=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ -n "${2:-}" ]] || {
        usage
        exit 1
      }
      root="$2"
      shift 2
      ;;
    --read-only)
      read_only=1
      shift
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done
if ((read_only)); then
  echo "Error: --read-only forbids audit filesystem writes. Produce audit inline and persist it through an authorized writer." >&2
  exit 2
fi
root=$(cd "$root" 2>/dev/null && pwd -P) || {
  echo "Error: Invalid root: $root" >&2
  exit 1
}
[[ -f "$TEMPLATE" ]] || {
  echo "Error: Canonical template missing: $TEMPLATE" >&2
  exit 1
}

dir="$root/docs/audits"
file="$dir/$(date +%Y-%m-%d)-lean-refactor-$scope.md"
[[ ! -e "$file" ]] || {
  echo "Error: Audit exists: $file" >&2
  exit 1
}
mkdir -p "$dir"
tmp="${file}.tmp.$$"
trap 'rm -f "$tmp"' EXIT

# Extract canonical fenced template through heading preceding non-template tips.
awk '
  /^```markdown$/ { in_template=1; next }
  in_template && /^## Tips$/ { exit }
  in_template { lines[++n]=$0 }
  END { if (!in_template || n < 2) exit 2; for (i=1; i<n; i++) print lines[i] }
' "$TEMPLATE" >"$tmp"

DATE_VALUE="$(date +%Y-%m-%d)" SCOPE_VALUE="$scope" perl -0pi -e '
  s/YYYY-MM-DD/$ENV{DATE_VALUE}/g;
  s/<plugins\/foo or whole-repo>/$ENV{SCOPE_VALUE}/g;
  s/\/lean-refactor <scope>/\/lean-refactor $ENV{SCOPE_VALUE}/g;
  s/# Lean Refactor — <scope>/# Lean Refactor — $ENV{SCOPE_VALUE}/g;
' "$tmp"

if git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commits=$(git -C "$root" log --oneline -30 --grep='refactor\|SSOT\|consolidate\|DRY' 2>/dev/null || true)
  [[ -n "$commits" ]] || commits="(no matching commits)"
else
  commits="(code-only mode: no Git history)"
fi
COMMITS="$commits" perl -0pi -e 's/- `<hash>` — <subject>\n- `<hash>` — <subject>\n- \(output of `git log[^\n]*\)/$ENV{COMMITS}/' "$tmp"

mv "$tmp" "$file"
trap - EXIT
printf '%s\n' "$file"
