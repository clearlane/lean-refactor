#!/usr/bin/env bats

# Depth selects where the workflow terminates; mode selects the isolation
# backing. These are independent axes, so the tests cover both the review
# terminal and the guarantee that a review can never reach mutation.

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export TEST_TMP="$BATS_TEST_TMPDIR/depth"
  mkdir -p "$TEST_TMP/repo"
  printf 'source\n' >"$TEST_TMP/repo/source.txt"
}

init_depth() {
  "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only --depth "$1" >"$TEST_TMP/setup.out"
  STATE=$(sed -n 's/^State: //p' "$TEST_TMP/setup.out")
  AUDIT="$TEST_TMP/repo/audit.md"
  printf '# Audit\n' >"$AUDIT"
}

reach_audit_ready() {
  local stage
  for stage in prior-art layers synthesis; do
    printf '%s\n' "$stage" >"$TEST_TMP/$stage"
    "$SCRIPT_DIR/workflow.sh" discovery "$STATE" --stage "$stage" --artifact "$TEST_TMP/$stage" >/dev/null
  done
  "$SCRIPT_DIR/workflow.sh" discovery "$STATE" --stage audit --artifact "$AUDIT" >/dev/null
  printf 'manifest\n' >"$TEST_TMP/wave"
}

approve_attempt() {
  "$SCRIPT_DIR/workflow.sh" approve "$STATE" "$AUDIT" --approver tester --findings F1 --tier 1 \
    --baseline-result "$TEST_TMP/wave" --reference-inventory "$TEST_TMP/wave" \
    --evidence "$TEST_TMP/wave" --classification "$TEST_TMP/wave" \
    --boundary-diff "$TEST_TMP/wave" --state-impact "$TEST_TMP/wave" \
    --external-impact "$TEST_TMP/wave" --wave-manifest "$TEST_TMP/wave"
}

@test "depth defaults to refactor so existing invocations keep their behavior" {
  run "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"Depth: refactor"* ]]
}

@test "an invalid depth is rejected before any state is created" {
  run "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only --depth audit
  [ "$status" -ne 0 ]
  [ ! -d "$TEST_TMP/repo/.claude" ]
}

@test "both depths are legal under either backing mode" {
  run "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only --depth review
  [ "$status" -eq 0 ]
  [[ "$output" == *"Mode: code-only"* ]]
  [[ "$output" == *"Depth: review"* ]]
}

@test "a review run reaches its own terminal phase" {
  init_depth review
  reach_audit_ready
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')

  run "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 3
  [ "$status" -eq 0 ]

  run "$SCRIPT_DIR/workflow.sh" status "$STATE"
  [[ "$output" == *"phase=reported"* ]]
  [[ "$output" == *"depth=review"* ]]
  [[ "$output" == *"approval_status=pending"* ]]
}

@test "a review with zero findings is still a valid terminal outcome" {
  init_depth review
  reach_audit_ready
  signature=$(printf '' | shasum -a 256 | awk '{print $1}')

  run "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 0
  [ "$status" -eq 0 ]
}

@test "a review run can never acquire approval" {
  init_depth review
  reach_audit_ready

  run approve_attempt
  [ "$status" -ne 0 ]
  [[ "$output" == *"depth=refactor"* ]]

  # The repair machinery stays unreachable because approval never landed.
  run "$SCRIPT_DIR/workflow.sh" status "$STATE"
  [[ "$output" == *"approval_status=pending"* ]]
}

@test "a refactor run cannot terminate through the review report" {
  init_depth refactor
  reach_audit_ready
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')

  run "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 3
  [ "$status" -ne 0 ]
  [[ "$output" == *"depth=review"* ]]
}

@test "a refactor run still reaches approval unchanged" {
  init_depth refactor
  reach_audit_ready

  run approve_attempt
  [ "$status" -eq 0 ]

  run "$SCRIPT_DIR/workflow.sh" status "$STATE"
  [[ "$output" == *"approval_status=approved"* ]]
  [[ "$output" == *"depth=refactor"* ]]
}

@test "review reporting requires completed discovery checkpoints" {
  init_depth review
  printf 'manifest\n' >"$TEST_TMP/wave"
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')

  # Phase is still 'discovery'; the terminal must refuse an unevidenced report.
  run "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 1
  [ "$status" -ne 0 ]
}

@test "a state carrying an unknown depth fails validation" {
  init_depth review
  sed -i.bak 's/^depth: "review"/depth: "audit"/' "$STATE"
  run "$SCRIPT_DIR/workflow.sh" status "$STATE"
  [ "$status" -ne 0 ]
}

@test "a published review resumes from persisted state alone" {
  init_depth review
  reach_audit_ready
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')
  "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 2 >/dev/null

  # Nothing but the state file survives a context reset, so the terminal phase
  # and depth must be readable from it without replaying the run.
  run "$SCRIPT_DIR/workflow.sh" status "$STATE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"phase=reported"* ]]
  [[ "$output" == *"depth=review"* ]]
}

@test "a reported review cannot be reported again" {
  init_depth review
  reach_audit_ready
  signature=$(printf 'F1' | shasum -a 256 | awk '{print $1}')
  "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 2 >/dev/null

  # Re-recording a terminal report would double-count findings in the audit.
  run "$SCRIPT_DIR/workflow.sh" report "$STATE" "$AUDIT" --manifest "$TEST_TMP/wave" \
    --current-signature "$signature" --finding-count 2
  [ "$status" -ne 0 ]
}
