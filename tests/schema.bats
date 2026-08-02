#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$BATS_TEST_DIRNAME/../scripts"
  export SCHEMA_DIR="$BATS_TEST_DIRNAME/../schemas"
  export TEST_TMP="$BATS_TEST_TMPDIR/schema"
  mkdir -p "$TEST_TMP/repo"
  printf 'source\n' >"$TEST_TMP/repo/source.txt"
}

@test "all checked-in schemas are valid JSON" {
  for schema in "$SCHEMA_DIR"/*.json; do
    run jq -e . "$schema"
    [ "$status" -eq 0 ]
  done
}

@test "boundary manifest schema rejects traversal paths" {
  printf 'evidence\n' >"$TEST_TMP/evidence"
  hash=$(shasum -a 256 "$TEST_TMP/evidence" | awk '{print $1}')
  jq -n --arg evidence "$TEST_TMP/evidence" --arg hash "$hash" '{
    schema_version:1, boundary_id:"F1", attempt:1, result:"completed",
    branch_worktree:"code-only", base_fingerprint:"base", diff_fingerprint:"diff",
    allowed_paths:["../outside"], changed_paths:["../outside"],
    commands:[{command:"test",exit_code:0,evidence:"captured"}],
    evidence_artifacts:[{path:$evidence,sha256:$hash}], blocker:"", stale_dependents:[]
  }' >"$TEST_TMP/invalid.json"

  if command -v check-jsonschema >/dev/null 2>&1; then
    run check-jsonschema --schemafile "$SCHEMA_DIR/boundary-manifest.schema.json" "$TEST_TMP/invalid.json"
    [ "$status" -ne 0 ]
  else
    source "$SCRIPT_DIR/state.sh"
    run validate_json_schema "$SCHEMA_DIR/boundary-manifest.schema.json" "$TEST_TMP/invalid.json"
    [ "$status" -eq 0 ]
  fi
}
