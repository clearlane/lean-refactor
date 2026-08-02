#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export SCHEMA_DIR="$BATS_TEST_DIRNAME/../schemas"
  export TEST_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$TEST_ROOT/src"
  printf 'hello() { printf "hello\\n"; }\n' >"$TEST_ROOT/src/example.sh"
  printf '# Example\n' >"$TEST_ROOT/README.md"
}

@test "repository frame is valid and inventories files without optional tools" {
  run "$SCRIPT_DIR/repo-frame.sh" "$TEST_ROOT" --output "$BATS_TEST_TMPDIR/frame.json"
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/frame.json" ]
  jq -e '
    .schema_version == 1 and
    (.root == $root or .root == $private_root) and
    .inventory.file_count == 2 and
    (.inventory.files | index("src/example.sh") != null) and
    (.inventory.files | index("README.md") != null) and
    (.codegraph.state | IN("unavailable", "not-initialized", "stale", "ready"))
  ' --arg root "$TEST_ROOT" --arg private_root "/private${TEST_ROOT}" "$BATS_TEST_TMPDIR/frame.json" >/dev/null

  if command -v check-jsonschema >/dev/null 2>&1; then
    run check-jsonschema --schemafile "$SCHEMA_DIR/repo-frame.schema.json" "$BATS_TEST_TMPDIR/frame.json"
    [ "$status" -eq 0 ]
  fi
}

@test "repository frame never initializes CodeGraph without explicit authorization" {
  [ ! -d "$TEST_ROOT/.codegraph" ]
  run "$SCRIPT_DIR/repo-frame.sh" "$TEST_ROOT" --output "$BATS_TEST_TMPDIR/frame.json"
  [ "$status" -eq 0 ]
  [ ! -d "$TEST_ROOT/.codegraph" ]
}

@test "invalid CPD thresholds are rejected" {
  run "$SCRIPT_DIR/repo-frame.sh" "$TEST_ROOT" --cpd-min-lines zero
  [ "$status" -eq 64 ]
}
