#!/bin/bash
# names.sh — enforce the skill resource filename convention.
#
# Usage:
#   names.sh [ROOT]
#
# Every authored file must use one lowercase word or a family-first lowercase
# hyphenated stem, with a conventional lowercase extension. Names required by a
# host, protocol, or ecosystem contract are preserved verbatim.
set -euo pipefail

root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[[ -d "$root" ]] || {
  echo "Usage: names.sh [ROOT]" >&2
  exit 64
}

# Exact names fixed by an external contract; see references/naming rule 7.
readonly EXACT_NAMES="LICENSE README.md SKILL.md SECURITY.md AGENTS.md CHANGELOG.md CONTRIBUTING.md UPSTREAM.md Makefile"
readonly STEM='^[a-z0-9]+(-[a-z0-9]+)*$'
readonly EXTENSIONS='^[a-z0-9]+(\.[a-z0-9]+)*$'
readonly BANNED_SEGMENTS="helper helpers util utils misc new temp tmp"

status=0
report() {
  printf '%s: %s\n' "$1" "$2" >&2
  status=1
}

while IFS= read -r relative; do
  name="${relative##*/}"
  [[ " $EXACT_NAMES " == *" $name "* ]] && continue

  stem="${name%%.*}"
  extensions=""
  [[ "$name" == *.* ]] && extensions="${name#*.}"

  if [[ ! "$stem" =~ $STEM ]]; then
    report "$relative" "use one lowercase word or a family-first lowercase hyphenated stem"
    continue
  fi
  if [[ -n "$extensions" && ! "$extensions" =~ $EXTENSIONS ]]; then
    report "$relative" "use a conventional lowercase extension"
    continue
  fi
  for segment in ${stem//-/ }; do
    if [[ " $BANNED_SEGMENTS " == *" $segment "* ]]; then
      report "$relative" "replace the generic segment '$segment' with the stable responsibility"
      break
    fi
  done
done < <(
  cd "$root" && find . -type f \
    -not -path './.*' \
    -not -path '*/.*' \
    -not -path './node_modules/*' \
    -print | LC_ALL=C sort | sed 's|^\./||'
)

exit "$status"
