#!/usr/bin/env bats

# The stop-hook adapter is the only component that runs unattended inside the
# host loop, so its fail-closed behavior is tested directly rather than assumed.

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export TEST_TMP="$BATS_TEST_TMPDIR/event"
  mkdir -p "$TEST_TMP/repo"
  printf 'source\n' >"$TEST_TMP/repo/source.txt"
}

init_state() {
  "$SCRIPT_DIR/workflow.sh" init "$TEST_TMP/repo" --code-only >"$TEST_TMP/setup.out"
  STATE=$(sed -n 's/^State: //p' "$TEST_TMP/setup.out")
  SESSION=$(sed -n 's/^Session ID: //p' "$TEST_TMP/setup.out")
}

write_transcript() {
  local text="$1"
  TRANSCRIPT="$TEST_TMP/transcript.jsonl"
  jq -nc --arg session "Session ID: $SESSION" '{role:"user",content:[{type:"text",text:$session}]}' >"$TRANSCRIPT"
  jq -nc --arg text "$text" '{role:"assistant",content:[{type:"text",text:$text}]}' >>"$TRANSCRIPT"
}

run_hook() {
  jq -nc --arg transcript "$TRANSCRIPT" --arg cwd "$TEST_TMP/repo" \
    '{transcript_path:$transcript,cwd:$cwd}' | "$SCRIPT_DIR/event-stop.sh"
}

@test "malformed hook input exits without blocking the host" {
  run bash -c "printf 'not json' | '$SCRIPT_DIR/event-stop.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
}

@test "a missing transcript exits without blocking the host" {
  run bash -c "jq -nc '{transcript_path:"/nonexistent/transcript.jsonl"}' | '$SCRIPT_DIR/event-stop.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" != *'"decision"'* ]]
}

@test "an unmatched session leaves unrelated runs untouched" {
  init_state
  SESSION="not-this-session"
  write_transcript "no marker"
  run run_hook
  [ "$status" -eq 0 ]
  [ -e "$STATE" ]
}

@test "corrupt state fails closed, blocks continuation, and preserves evidence" {
  init_state
  write_transcript "no marker"
  printf 'corrupted\n' >"$STATE"

  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision"'* ]]
  [[ "$output" == *block* ]]

  # The corrupt state is preserved verbatim and recorded as separate evidence.
  [ "$(cat "$STATE")" = "corrupted" ]
  [ -f "${STATE}.failure" ]
}

@test "an unsupported marker blocks continuation and records failure evidence" {
  init_state
  write_transcript "<lean-refactor-complete>"

  run run_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *block* ]]
  [[ "$output" == *"Marker rejected"* ]]

  # A complete marker with no audit-backed wave must never terminate the run.
  [ -e "$STATE" ]
  source "$SCRIPT_DIR/state.sh"
  [ "$(parse_field "$STATE" phase)" = "discovery" ]
  [ "$(parse_field "$STATE" iteration)" = "1" ]
  # The rejection is recorded as failure evidence rather than silently ignored.
  [ "$(parse_field "$STATE" failure_count)" = "1" ]
}
