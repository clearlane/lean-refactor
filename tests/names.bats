#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export TEST_ROOT="$BATS_TEST_TMPDIR/names"
  mkdir -p "$TEST_ROOT/scripts" "$BATS_TEST_TMPDIR/consumed"
  touch "$TEST_ROOT/README.md" "$TEST_ROOT/SKILL.md" "$TEST_ROOT/LICENSE"
  touch "$TEST_ROOT/scripts/state.sh" "$TEST_ROOT/scripts/loop-setup.sh"
  touch "$TEST_ROOT/scripts/schema-v2.json" "$TEST_ROOT/scripts/archive.tar.gz"
}

@test "conventional names and contract-fixed names are accepted" {
  run "$SCRIPT_DIR/names.sh" "$TEST_ROOT"
  [ "$status" -eq 0 ]
}

@test "each convention violation is rejected with a reason" {
  invalid=(
    "resolve_settings.py"
    "CreateCommand.md"
    "command review.md"
    "loop--setup.sh"
    "command-create.MD"
    "state-utils.sh"
    "loop-helper.sh"
    "new-schema.json"
  )
  for name in "${invalid[@]}"; do
    touch "$TEST_ROOT/scripts/$name"
    run "$SCRIPT_DIR/names.sh" "$TEST_ROOT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$name"* ]]
    mv "$TEST_ROOT/scripts/$name" "$BATS_TEST_TMPDIR/consumed/"
  done
}

@test "the live skill tree satisfies the naming convention" {
  run "$SCRIPT_DIR/names.sh" "$BATS_TEST_DIRNAME/.."
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
