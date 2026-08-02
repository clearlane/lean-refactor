#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export TEST_TMP="$BATS_TEST_TMPDIR/case"
  mkdir -p "$TEST_TMP/repo"
  printf 'source\n' >"$TEST_TMP/repo/source.txt"
}

init_discovery() {
  "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only >"$TEST_TMP/setup.out"
  STATE=$(sed -n 's/^State: //p' "$TEST_TMP/setup.out")
  AUDIT="$TEST_TMP/repo/audit.md"
  printf '# Audit\n' >"$AUDIT"
  for name in prior-art layers synthesis; do
    printf '%s\n' "$name" >"$TEST_TMP/$name"
    "$SCRIPT_DIR/workflow.sh" discovery "$STATE" --stage "$name" --artifact "$TEST_TMP/$name" >/dev/null
  done
  "$SCRIPT_DIR/workflow.sh" discovery "$STATE" --stage audit --artifact "$AUDIT" >/dev/null
}

make_approval_artifacts() {
  for name in baseline refs evidence classification boundary state-impact external-impact wave; do
    printf '%s\n' "$name" >"$TEST_TMP/$name"
  done
}

approve_f1() {
  make_approval_artifacts
  "$SCRIPT_DIR/workflow.sh" approve "$STATE" "$AUDIT" --approver tester --findings F1 --tier 1 \
    --baseline-result "$TEST_TMP/baseline" --reference-inventory "$TEST_TMP/refs" \
    --evidence "$TEST_TMP/evidence" --classification "$TEST_TMP/classification" \
    --boundary-diff "$TEST_TMP/boundary" --state-impact "$TEST_TMP/state-impact" \
    --external-impact "$TEST_TMP/external-impact" --wave-manifest "$TEST_TMP/wave" >/dev/null
}

write_manifest() {
  local file="$1" kind_result="$2" attempt="$3" blocker="${4:-}"
  printf 'evidence\n' >"$TEST_TMP/boundary-evidence"
  local hash
  hash=$(shasum -a 256 "$TEST_TMP/boundary-evidence" | awk '{print $1}')
  jq -n --arg result "$kind_result" --argjson attempt "$attempt" --arg blocker "$blocker" \
    --arg evidence "$TEST_TMP/boundary-evidence" --arg hash "$hash" '{
      schema_version:1, boundary_id:"F1", attempt:$attempt, result:$result,
      branch_worktree:"code-only", base_fingerprint:"base", diff_fingerprint:"diff",
      allowed_paths:["source.txt"], changed_paths:["source.txt"],
      commands:[{command:"test",exit_code:0,evidence:"captured"}],
      evidence_artifacts:[{path:$evidence,sha256:$hash}], blocker:$blocker, stale_dependents:[]
    }' >"$file"
}

@test "approval binds artifacts and becomes stale after source mutation" {
  init_discovery
  approve_f1

  run "$SCRIPT_DIR/workflow.sh" verify-approval "$STATE"
  [ "$status" -eq 0 ]

  printf 'changed\n' >"$TEST_TMP/repo/source.txt"
  run "$SCRIPT_DIR/workflow.sh" verify-approval "$STATE"
  [ "$status" -ne 0 ]
}

@test "boundary workflow rejects invalid paths and enforces repair before verification" {
  init_discovery
  approve_f1
  write_manifest "$TEST_TMP/repair.json" completed 1
  jq '.changed_paths=["outside.txt"]' "$TEST_TMP/repair.json" >"$TEST_TMP/outside.json"

  run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind repair --result completed --manifest "$TEST_TMP/outside.json"
  [ "$status" -ne 0 ]

  write_manifest "$TEST_TMP/verify-early.json" completed 1
  run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind verification --result completed --manifest "$TEST_TMP/verify-early.json"
  [ "$status" -ne 0 ]

  run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind repair --result completed --manifest "$TEST_TMP/repair.json"
  [ "$status" -eq 0 ]
  write_manifest "$TEST_TMP/verify.json" completed 1
  run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind verification --result completed --manifest "$TEST_TMP/verify.json"
  [ "$status" -eq 0 ]
}

@test "zero-finding conclusion requires audit-backed completion before advance" {
  init_discovery
  make_approval_artifacts
  signature=$(printf '' | shasum -a 256 | awk '{print $1}')

  run "$SCRIPT_DIR/workflow.sh" conclude-discovery "$STATE" "$AUDIT" \
    --manifest "$TEST_TMP/wave" --current-signature "$signature" --repair-ready-count 0
  [ "$status" -eq 0 ]

  printf '<lean-refactor-complete>\n' >"$TEST_TMP/last-output"
  run "$SCRIPT_DIR/workflow.sh" advance "$STATE" --last-output "$TEST_TMP/last-output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"terminal=complete"* ]]
  [ ! -e "$STATE" ]
}

@test "cancellation refuses a busy state and succeeds after lock release" {
  run "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only
  [ "$status" -eq 0 ]
  STATE=$(sed -n 's/^State: //p' <<<"$output")
  mkdir "${STATE}.lock"

  run "$SCRIPT_DIR/workflow.sh" cancel --root "$TEST_TMP/repo"
  [ "$status" -ne 0 ]
  [ -e "$STATE" ]

  rmdir "${STATE}.lock"
  run "$SCRIPT_DIR/workflow.sh" cancel --root "$TEST_TMP/repo"
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}

@test "an exhausted repair budget becomes terminal and blocks wave finalization" {
  init_discovery
  approve_f1

  for attempt in 1 2; do
    write_manifest "$TEST_TMP/fail-$attempt.json" failed "$attempt" "repair command failed"
    run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind repair \
      --result failed --manifest "$TEST_TMP/fail-$attempt.json"
    [ "$status" -eq 0 ]
  done

  # The budget is spent, so no further repair may be recorded for this boundary.
  write_manifest "$TEST_TMP/late.json" completed 3
  run "$SCRIPT_DIR/workflow.sh" boundary "$STATE" --boundary F1 --kind repair \
    --result completed --manifest "$TEST_TMP/late.json"
  [ "$status" -ne 0 ]

  run bash -c "source '$SCRIPT_DIR/state.sh'; boundary_ledger_ready '$STATE'"
  [ "$status" -ne 0 ]

  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')
  run "$SCRIPT_DIR/workflow.sh" finalize "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --repair-ready-count 0 --approval-required no
  [ "$status" -ne 0 ]
}

@test "the stuck marker requires identical signatures in both audit and state" {
  init_discovery
  make_approval_artifacts
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')

  run "$SCRIPT_DIR/workflow.sh" conclude-discovery "$STATE" "$AUDIT" \
    --manifest "$TEST_TMP/wave" --current-signature "$signature" \
    --previous-signature "$signature" --repair-ready-count 0
  [ "$status" -eq 0 ]

  run bash -c "source '$SCRIPT_DIR/state.sh'; validate_terminal_audit '$STATE' stuck"
  [ "$status" -eq 0 ]

  # A signature that no longer matches persisted state must not read as stuck.
  run bash -c "source '$SCRIPT_DIR/state.sh'; update_field '$STATE' previous_signature 'deadbeef'; validate_terminal_audit '$STATE' stuck"
  [ "$status" -ne 0 ]
}
