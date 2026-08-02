#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
root="$tmp/repo"
mkdir -p "$root"
printf 'source\n' >"$root/source.txt"
"$SCRIPT_DIR/setup-loop.sh" "$root" --code-only >"$tmp/setup.out"
state=$(sed -n 's/^State: //p' "$tmp/setup.out")
audit="$root/audit.md"
printf '# Audit\n' >"$audit"
for artifact in baseline refs evidence classification boundary state-impact external-impact wave; do
  printf '%s\n' "$artifact" >"$tmp/$artifact"
done
"$SCRIPT_DIR/record-approval.sh" "$state" "$audit" --findings F1 --tier 1 \
  --baseline-result "$tmp/baseline" --reference-inventory "$tmp/refs" \
  --evidence "$tmp/evidence" --classification "$tmp/classification" \
  --boundary-diff "$tmp/boundary" --state-impact "$tmp/state-impact" \
  --external-impact "$tmp/external-impact" --wave-manifest "$tmp/wave" >/dev/null
[[ "$(parse_field "$state" expected_wave_status)" == pending ]]
if validate_wave "$state"; then exit 1; fi
printf 'repaired\n' >"$root/source.txt"
if validate_approval "$state"; then exit 1; fi
validate_approval_envelope "$state"
signature=$(printf 'F1' | sha256_stream)
"$SCRIPT_DIR/record-wave.sh" "$state" "$audit" --manifest "$tmp/wave" \
  --current-signature "$signature" --repair-ready-count 0 --approval-required no >/dev/null
[[ "$(parse_field "$state" expected_wave_status)" == complete ]]
validate_wave "$state"
validate_approval_envelope "$state"
validate_terminal_audit "$state" complete
printf '\ncompound_approval_required: invalid\n' >>"$audit"
update_field "$state" audit_hash "$(sha256_file "$audit")"
if validate_terminal_audit "$state" complete; then exit 1; fi
printf '\ncompound_approval_required: no\ncompound_current_signature: %s\ncompound_previous_signature: %s\n' "$signature" "$signature" >>"$audit"
update_field "$state" previous_signature "$signature"
update_field "$state" audit_hash "$(sha256_file "$audit")"
validate_terminal_audit "$state" stuck
printf '\ncompound_approval_required:\n' >>"$audit"
update_field "$state" audit_hash "$(sha256_file "$audit")"
if validate_terminal_audit "$state" stuck; then exit 1; fi
printf '\ncompound_approval_required: yes\n' >>"$audit"
update_field "$state" audit_hash "$(sha256_file "$audit")"
update_field "$state" approval_status pending
if validate_terminal_audit "$state" stuck; then exit 1; fi
update_field "$state" approval_status approved
printf 'stale\n' >>"$tmp/evidence"
if validate_terminal_audit "$state" stuck; then exit 1; fi
printf 'Lifecycle self-check: PASS\n'
