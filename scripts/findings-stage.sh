#!/usr/bin/env bash
# findings-stage.sh — concatenate parallel agent reports into one file.
#
# Usage:
#   findings-stage.sh <findings-dir>
#
# Where findings-dir contains one .md file per agent report (any pre-existing
# master.md is skipped). Output is findings-dir/master.md: an index plus each
# report's raw text. Dedupe and tier ranking stay with the orchestrator.
#
# This script is OPTIONAL — the orchestrator can also do this assembly inline.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <findings-dir>" >&2
  exit 64
fi

dir="$1"
if [[ ! -d "$dir" ]]; then
  echo "Not a directory: $dir" >&2
  exit 1
fi

out="$dir/master.md"

shopt -s nullglob
reports=()
for f in "$dir"/*.md; do
  [[ "$f" == "$out" ]] && continue
  reports+=("$f")
done
if [[ ${#reports[@]} -eq 0 ]]; then
  echo "No .md files in $dir" >&2
  exit 1
fi

{
  echo "# Lean-Refactor Master List"
  echo
  echo "Assembled from ${#reports[@]} agent report(s) on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
  echo
  echo "## Source reports"
  for r in "${reports[@]}"; do
    echo "- \`$(basename "$r")\` ($(wc -l <"$r" | tr -d ' ') lines)"
  done
  echo
  echo "---"
  echo
  echo "## Raw findings (sorted by file)"
  echo
  echo "Each agent's full output preserved below. The orchestrator should"
  echo "deduplicate across reports, then re-rank into Tier 1–4 buckets."
  echo
  for r in "${reports[@]}"; do
    echo "## From: $(basename "$r")"
    echo
    cat "$r"
    echo
    echo "---"
    echo
  done
} >"$out"

echo "Wrote $out"
echo "Next: dedupe across reports and rank into tiers per references/ranking.md"
