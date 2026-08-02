#!/bin/bash
# check.sh — the repository's single handoff check list.
#
# SKILL.md, README.md, and CI all invoke this script instead of restating the
# command sequence, so the three surfaces cannot drift apart.
#
# Usage:
#   check.sh [--strict]
#
# --strict requires every optional checker to be installed and enables full
# JSON Schema validation. CI uses it; local runs skip missing optional tools.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

strict=0
[[ "${1:-}" != "--strict" ]] || strict=1
[[ $# -le 1 ]] || {
  echo "Usage: check.sh [--strict]" >&2
  exit 64
}
((!strict)) || export LEAN_REFACTOR_STRICT_SCHEMA=1

status=0
run_check() {
  local name="$1"
  shift
  if "$@"; then
    printf 'ok   %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name" >&2
    status=1
  fi
}

# An optional checker is fatal only under --strict, so CI cannot silently skip it.
require() {
  local tool="$1" name="$2"
  command -v "$tool" >/dev/null 2>&1 && return 0
  if ((strict)); then
    printf 'FAIL %s (%s is not installed)\n' "$name" "$tool" >&2
    status=1
  else
    printf 'skip %s (%s is not installed)\n' "$name" "$tool"
  fi
  return 1
}

shopt -s nullglob
scripts=(scripts/*.sh)
tests=(tests/*.bats)

run_check 'shell syntax' bash -n "${scripts[@]}"
! require shellcheck 'shellcheck' || run_check 'shellcheck' shellcheck -S warning "${scripts[@]}"
! require shfmt 'shell formatting' || run_check 'shell formatting' shfmt -d -i 2 -ci "${scripts[@]}" "${tests[@]}"
run_check 'resource filenames' bash scripts/names.sh
run_check 'lifecycle' bash scripts/lifecycle-check.sh

validate_schemas() {
  local schema frame result=0
  for schema in schemas/*.json; do
    jq -e . "$schema" >/dev/null || return 1
  done
  frame=$(mktemp)
  if ! scripts/repo-frame.sh . --output "$frame" >/dev/null; then
    result=1
  elif command -v check-jsonschema >/dev/null 2>&1; then
    check-jsonschema --schemafile schemas/repo-frame.schema.json "$frame" >/dev/null || result=1
  elif ((strict)); then
    result=1
  fi
  rm -f "$frame"
  return "$result"
}
run_check 'schemas and repository frame' validate_schemas

exit "$status"
