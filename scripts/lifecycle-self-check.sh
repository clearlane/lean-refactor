#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
root="$tmp/repo"
mkdir -p "$root"
printf 'source\n' >"$root/source.txt"
"$SCRIPT_DIR/workflow.sh" init "$root" --code-only >"$tmp/setup.out"
state=$(sed -n 's/^State: //p' "$tmp/setup.out")
audit="$root/audit.md"
printf '# Audit\n' >"$audit"
for artifact in baseline refs evidence classification boundary state-impact external-impact wave; do
  printf '%s\n' "$artifact" >"$tmp/$artifact"
done
for stage in prior-art layers synthesis audit; do
  printf '%s\n' "$stage" >"$tmp/$stage"
  "$SCRIPT_DIR/workflow.sh" discovery "$state" --stage "$stage" --artifact "$tmp/$stage" >/dev/null
done
"$SCRIPT_DIR/workflow.sh" approve "$state" "$audit" --approver tester --conditions none --findings F1 --tier 1 \
  --baseline-result "$tmp/baseline" --reference-inventory "$tmp/refs" \
  --evidence "$tmp/evidence" --classification "$tmp/classification" \
  --boundary-diff "$tmp/boundary" --state-impact "$tmp/state-impact" \
  --external-impact "$tmp/external-impact" --wave-manifest "$tmp/wave" >/dev/null
[[ "$(parse_field "$state" expected_wave_status)" == pending ]]
if validate_wave "$state"; then exit 1; fi
printf 'repaired\n' >"$root/source.txt"
if validate_approval "$state"; then exit 1; fi
validate_approval_envelope "$state"
boundary_manifest="$tmp/boundary-result"
printf 'boundary attempt\n' >"$boundary_manifest"
if "$SCRIPT_DIR/record-boundary-result.sh" "$state" --boundary F2 --kind repair --result completed --manifest "$boundary_manifest" >/dev/null 2>&1; then exit 1; fi
if "$SCRIPT_DIR/record-boundary-result.sh" "$state" --boundary F1 --kind verification --result completed --manifest "$boundary_manifest" >/dev/null 2>&1; then exit 1; fi
"$SCRIPT_DIR/workflow.sh" boundary "$state" --boundary F1 --kind repair --result retryable --manifest "$boundary_manifest" >/dev/null
if boundary_ledger_ready "$state"; then exit 1; fi
"$SCRIPT_DIR/workflow.sh" boundary "$state" --boundary F1 --kind repair --result completed --manifest "$boundary_manifest" >/dev/null
if boundary_ledger_ready "$state"; then exit 1; fi
"$SCRIPT_DIR/workflow.sh" boundary "$state" --boundary F1 --kind verification --result completed --manifest "$boundary_manifest" >/dev/null
boundary_ledger_ready "$state"
signature=$(printf 'F1' | sha256_stream)
"$SCRIPT_DIR/workflow.sh" finalize "$state" "$audit" --manifest "$tmp/wave" \
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

blocked_root="$tmp/blocked-repo"
mkdir -p "$blocked_root"
printf 'source\n' >"$blocked_root/source.txt"
"$SCRIPT_DIR/workflow.sh" init "$blocked_root" --code-only >"$tmp/blocked-setup.out"
blocked_state=$(sed -n 's/^State: //p' "$tmp/blocked-setup.out")
blocked_audit="$blocked_root/audit.md"
printf '# Audit\n' >"$blocked_audit"
for stage in prior-art layers synthesis audit; do
  "$SCRIPT_DIR/workflow.sh" discovery "$blocked_state" --stage "$stage" --artifact "$tmp/$stage" >/dev/null
done
"$SCRIPT_DIR/workflow.sh" approve "$blocked_state" "$blocked_audit" --approver tester --findings B1 --tier 1 \
  --baseline-result "$tmp/baseline" --reference-inventory "$tmp/refs" \
  --evidence "$tmp/classification" --classification "$tmp/classification" \
  --boundary-diff "$tmp/boundary" --state-impact "$tmp/state-impact" \
  --external-impact "$tmp/external-impact" --wave-manifest "$tmp/wave" >/dev/null
"$SCRIPT_DIR/workflow.sh" boundary "$blocked_state" --boundary B1 --kind repair --result failed --manifest "$boundary_manifest" >/dev/null
"$SCRIPT_DIR/workflow.sh" boundary "$blocked_state" --boundary B1 --kind repair --result failed --manifest "$boundary_manifest" >/dev/null
if boundary_ledger_ready "$blocked_state"; then exit 1; fi
if "$SCRIPT_DIR/workflow.sh" boundary "$blocked_state" --boundary B1 --kind repair --result completed --manifest "$boundary_manifest" >/dev/null 2>&1; then exit 1; fi
if "$SCRIPT_DIR/workflow.sh" finalize "$blocked_state" "$blocked_audit" --manifest "$tmp/wave" \
  --current-signature "$signature" --repair-ready-count 0 --approval-required no >/dev/null 2>&1; then exit 1; fi

complete_root="$tmp/complete-repo"
mkdir -p "$complete_root"
printf 'source\n' >"$complete_root/source.txt"
"$SCRIPT_DIR/workflow.sh" init "$complete_root" --code-only >"$tmp/complete-setup.out"
complete_state=$(sed -n 's/^State: //p' "$tmp/complete-setup.out")
complete_audit="$complete_root/audit.md"
printf '# Audit\n' >"$complete_audit"
for stage in prior-art layers synthesis audit; do
  "$SCRIPT_DIR/workflow.sh" discovery "$complete_state" --stage "$stage" --artifact "$tmp/$stage" >/dev/null
done
empty_signature=$(printf '' | sha256_stream)
"$SCRIPT_DIR/workflow.sh" conclude-discovery "$complete_state" "$complete_audit" \
  --manifest "$tmp/wave" --current-signature "$empty_signature" --repair-ready-count 0 >/dev/null
validate_terminal_audit "$complete_state" complete
printf '<lean-refactor-complete>\n' >"$tmp/last-output"
advance_result=$("$SCRIPT_DIR/workflow.sh" advance "$complete_state" --last-output "$tmp/last-output")
[[ "$advance_result" == *'terminal=complete'* ]]
[[ ! -e "$complete_state" ]]
printf 'Lifecycle self-check: PASS\n'
