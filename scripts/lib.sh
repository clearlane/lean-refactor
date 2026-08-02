#!/bin/bash

readonly COMPOUND_STATE_SCHEMA_VERSION=8
readonly COMPOUND_STATE_PREFIX="lean-refactor."
readonly COMPOUND_STATE_SUFFIX=".local.md"
readonly COMPOUND_STATE_FIELDS="schema_version session_id phase iteration max_iterations tier_floor mode root_path scope_path baseline_commit audit_file audit_hash approval_status approval_digest approval_recorded_at approver approval_conditions approved_findings approved_tier approval_exclusions repository_fingerprint baseline_result_artifact baseline_result_hash reference_inventory_artifact reference_inventory_hash evidence_artifact evidence_hash classification_artifact classification_hash boundary_diff_artifact boundary_diff_hash state_impact_artifact state_impact_hash external_impact_artifact external_impact_hash discovery_ledger discovery_ledger_hash boundary_ledger boundary_ledger_hash current_signature previous_signature expected_wave_manifest expected_wave_manifest_hash expected_wave_status failure_count failure_limit last_failure"
readonly COMPOUND_OPTIONAL_FIELDS="audit_file audit_hash approval_digest approval_recorded_at approver approval_conditions approved_findings approved_tier approval_exclusions repository_fingerprint baseline_result_artifact baseline_result_hash reference_inventory_artifact reference_inventory_hash evidence_artifact evidence_hash classification_artifact classification_hash boundary_diff_artifact boundary_diff_hash state_impact_artifact state_impact_hash external_impact_artifact external_impact_hash current_signature previous_signature expected_wave_manifest expected_wave_manifest_hash expected_wave_status last_failure"
COMPOUND_STATE_LOCK=""

acquire_state_lock() {
  local file="$1" lock
  [[ "$file" == /* && -d "$(dirname "$file")" ]] || return 1
  lock="${file}.lock"
  mkdir "$lock" 2>/dev/null || return 1
  COMPOUND_STATE_LOCK="$lock"
  printf '%s\n' "$$" >"$lock/pid"
}

release_state_lock() {
  [[ -n "$COMPOUND_STATE_LOCK" ]] || return 0
  rm -rf "$COMPOUND_STATE_LOCK"
  COMPOUND_STATE_LOCK=""
}

parse_field() {
  local file="$1" key="$2"
  sed -n '/^---$/,/^---$/{
    /^'"$key"':/{ s/'"$key"': *//; s/^["'"'"']//; s/["'"'"']$//; p; q; }
  }' "$file" 2>/dev/null || true
}

resolve_directory() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  (cd "$path" 2>/dev/null && pwd -P)
}
resolve_root() {
  local scope mode="${2:-auto}" root
  scope=$(resolve_directory "$1") || return 1
  if [[ "$mode" != "code-only" ]] && root=$(git -C "$scope" rev-parse --show-toplevel 2>/dev/null); then
    resolve_directory "$root"
  elif [[ "$mode" == "code-only" ]]; then
    printf '%s\n' "$scope"
  else
    return 2
  fi
}
state_dir() { printf '%s/.claude\n' "$1"; }
state_path() { printf '%s/%s%s%s\n' "$(state_dir "$1")" "$COMPOUND_STATE_PREFIX" "$2" "$COMPOUND_STATE_SUFFIX"; }
extract_session_id() {
  local name
  name=$(basename "$1")
  name=${name#"$COMPOUND_STATE_PREFIX"}
  printf '%s\n' "${name%"$COMPOUND_STATE_SUFFIX"}"
}
valid_session_id() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }
list_state_files() {
  local root="$1" dir file
  dir=$(state_dir "$root")
  [[ -d "$dir" ]] || return 0
  shopt -s nullglob
  for file in "$dir"/"$COMPOUND_STATE_PREFIX"*"$COMPOUND_STATE_SUFFIX"; do printf '%s\n' "$file"; done
  shopt -u nullglob
}

sha256_stream() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
sha256_file() {
  [[ -f "$1" ]] || return 1
  sha256_stream <"$1"
}
canonical_digest() { printf '%s\0' "$@" | sha256_stream; }

write_state() {
  local file="$1" session_id="$2" max_iterations="$3" tier_floor="$4" mode="$5" root="$6" scope="$7" baseline="$8" tmp ledger discovery
  ledger="${file%.local.md}.boundaries.json"
  discovery="${file%.local.md}.discovery.json"
  printf '{"schema_version":2,"session_id":"%s","boundaries":{}}\n' "$session_id" >"$ledger"
  printf '{"schema_version":1,"session_id":"%s","iterations":{}}\n' "$session_id" >"$discovery"
  tmp="${file}.tmp.$$"
  cat >"$tmp" <<EOF
---
schema_version: "$COMPOUND_STATE_SCHEMA_VERSION"
session_id: "$session_id"
phase: "discovery"
iteration: "1"
max_iterations: "$max_iterations"
tier_floor: "$tier_floor"
mode: "$mode"
root_path: "$root"
scope_path: "$scope"
baseline_commit: "$baseline"
audit_file: ""
audit_hash: ""
approval_status: "pending"
approval_digest: ""
approval_recorded_at: ""
approver: ""
approval_conditions: ""
approved_findings: ""
approved_tier: ""
approval_exclusions: ""
repository_fingerprint: ""
baseline_result_artifact: ""
baseline_result_hash: ""
reference_inventory_artifact: ""
reference_inventory_hash: ""
evidence_artifact: ""
evidence_hash: ""
classification_artifact: ""
classification_hash: ""
boundary_diff_artifact: ""
boundary_diff_hash: ""
state_impact_artifact: ""
state_impact_hash: ""
external_impact_artifact: ""
external_impact_hash: ""
discovery_ledger: "$discovery"
discovery_ledger_hash: "$(sha256_file "$discovery")"
boundary_ledger: "$ledger"
boundary_ledger_hash: "$(sha256_file "$ledger")"
current_signature: ""
previous_signature: ""
expected_wave_manifest: ""
expected_wave_manifest_hash: ""
expected_wave_status: ""
failure_count: "0"
failure_limit: "2"
last_failure: ""
---
EOF
  mv "$tmp" "$file"
}

validate_state() {
  local file="$1" key value sid root scope optional ledger discovery
  [[ -f "$file" ]] || return 1
  for key in $COMPOUND_STATE_FIELDS; do
    value=$(parse_field "$file" "$key")
    optional=" $COMPOUND_OPTIONAL_FIELDS "
    [[ -n "$value" || "$optional" == *" $key "* ]] || return 1
  done
  [[ "$(parse_field "$file" schema_version)" == "$COMPOUND_STATE_SCHEMA_VERSION" ]] || return 1
  sid=$(parse_field "$file" session_id)
  valid_session_id "$sid" || return 1
  [[ "$(extract_session_id "${COMPOUND_STATE_CANONICAL_PATH:-$file}")" == "$sid" ]] || return 1
  [[ "$(parse_field "$file" iteration)" =~ ^[1-9][0-9]*$ && "$(parse_field "$file" max_iterations)" =~ ^[1-9][0-9]*$ ]] || return 1
  [[ "$(parse_field "$file" tier_floor)" =~ ^[1-4]$ && "$(parse_field "$file" failure_count)" =~ ^[0-9]+$ && "$(parse_field "$file" failure_limit)" =~ ^[1-9][0-9]*$ ]] || return 1
  [[ "$(parse_field "$file" failure_limit)" == 2 ]] || return 1
  [[ "$(parse_field "$file" phase)" =~ ^(discovery|prior_art|layer_scans|synthesis|audit_ready|approved|repair|verification|rediscovery|blocked)$ ]] || return 1
  [[ "$(parse_field "$file" mode)" =~ ^(git|code-only)$ && "$(parse_field "$file" approval_status)" =~ ^(pending|approved|revoked)$ ]] || return 1
  root=$(parse_field "$file" root_path)
  scope=$(parse_field "$file" scope_path)
  [[ "$root" == /* && -d "$root" && "$scope" == /* && -d "$scope" ]] || return 1
  local canonical_state="${COMPOUND_STATE_CANONICAL_PATH:-$file}"
  [[ "$canonical_state" == "$(state_path "$root" "$sid")" ]] || return 1
  ledger=$(parse_field "$file" boundary_ledger)
  [[ "$ledger" == "${canonical_state%.local.md}.boundaries.json" && -f "$ledger" && "$(sha256_file "$ledger")" == "$(parse_field "$file" boundary_ledger_hash)" ]] || return 1
  discovery=$(parse_field "$file" discovery_ledger)
  [[ "$discovery" == "${canonical_state%.local.md}.discovery.json" && -f "$discovery" && "$(sha256_file "$discovery")" == "$(parse_field "$file" discovery_ledger_hash)" ]] || return 1
}

validate_discovery_ledger() {
  local state="$1" ledger artifact expected_hash
  validate_state "$state" || return 1
  ledger=$(parse_field "$state" discovery_ledger)
  jq -e --arg sid "$(parse_field "$state" session_id)" '
    .schema_version == 1 and .session_id == $sid and (.iterations | type == "object") and
    ([.iterations[] | [.prior_art, .layers, .synthesis, .audit][] |
      (.status | IN("pending", "completed")) and
      (.artifact | type == "string") and (.artifact_hash | type == "string")
    ] | all)
  ' "$ledger" >/dev/null || return 1
  while IFS=$'\t' read -r artifact expected_hash; do
    [[ "$artifact" == /* && -f "$artifact" && "$(sha256_file "$artifact")" == "$expected_hash" ]] || return 1
  done < <(jq -r '.iterations[] | [.prior_art, .layers, .synthesis, .audit][] | select(.status == "completed") | [.artifact, .artifact_hash] | @tsv' "$ledger")
}

validate_boundary_ledger() {
  local state="$1" ledger manifest expected_hash
  validate_state "$state" || return 1
  ledger=$(parse_field "$state" boundary_ledger)
  jq -e --arg sid "$(parse_field "$state" session_id)" '
    .schema_version == 2 and .session_id == $sid and (.boundaries | type == "object") and
    ([.boundaries[] | . as $boundary |
      (.status | IN("pending", "completed", "blocked")) and
      (.repair_attempts | type == "number" and . >= 0) and
      (.verification_failures | type == "number" and . >= 0) and
      (.repair_limit | type == "number" and . >= 1) and
      (.verification_limit | type == "number" and . >= 1) and
      (.repair_status | IN("pending", "completed", "blocked")) and
      (.verification_status | IN("pending", "completed", "blocked")) and
      (.last_result | type == "string") and
      (.last_manifest | type == "string") and
      (.last_manifest_hash | type == "string") and
      (.history | type == "array") and
      ([.history[] |
        (.kind | IN("repair", "verification")) and
        (.result | IN("completed", "retryable", "failed", "blocked")) and
        (.attempt | type == "number" and . >= 1 and floor == .) and
        (.manifest | type == "string" and startswith("/")) and
        (.manifest_hash | type == "string" and test("^[0-9a-f]{64}$")) and
        (.recorded_at | type == "string" and length > 0)
      ] | all) and
      ([.history[].manifest] | length == (unique | length)) and
      ([.history[] | select(.kind == "repair") | .attempt] == [range(1; $boundary.repair_attempts + 1)]) and
      ([.history[] | select(.kind == "verification") | .attempt] ==
        [range(1; ([.history[] | select(.kind == "verification")] | length) + 1)]) and
      ($boundary.verification_failures ==
        ([.history[] | select(.kind == "verification" and (.result == "retryable" or .result == "failed"))] | length)) and
      (if (.history | length) == 0 then
        .last_result == "" and .last_manifest == "" and .last_manifest_hash == "" and .recorded_at == ""
       else
        .history[-1] as $last |
        .last_result == ($last.kind + ":" + $last.result) and
        .last_manifest == $last.manifest and .last_manifest_hash == $last.manifest_hash and
        .recorded_at == $last.recorded_at
       end) and
      (.repair_status ==
        (if any(.history[]; .kind == "repair" and .result == "completed") then "completed"
         elif any(.history[]; .kind == "repair" and .result == "blocked") or .repair_attempts >= .repair_limit then "blocked"
         else "pending" end)) and
      (.verification_status ==
        (if any(.history[]; .kind == "verification" and .result == "completed") then "completed"
         elif any(.history[]; .kind == "verification" and .result == "blocked") or .verification_failures >= .verification_limit then "blocked"
         else "pending" end)) and
      (.status ==
        (if .repair_status == "blocked" or .verification_status == "blocked" then "blocked"
         elif .repair_status == "completed" and .verification_status == "completed" then "completed"
         else "pending" end))
    ] | all)
  ' "$ledger" >/dev/null || return 1
  while IFS=$'\t' read -r manifest expected_hash; do
    [[ "$manifest" == /* && -f "$manifest" && "$(sha256_file "$manifest")" == "$expected_hash" ]] || return 1
  done < <(jq -r '.boundaries[].history[] | [.manifest, .manifest_hash] | @tsv' "$ledger")
}

boundary_ledger_ready() {
  local state="$1" ledger
  validate_boundary_ledger "$state" || return 1
  ledger=$(parse_field "$state" boundary_ledger)
  jq -e '[.boundaries[] | select(.status != "completed")] | length == 0' "$ledger" >/dev/null
}

update_fields() {
  local file="$1" tmp key value assignments="" separator=""
  shift
  (($# >= 2 && $# % 2 == 0)) || return 1
  while (($# > 0)); do
    key="$1"
    value="$2"
    shift 2
    [[ " $COMPOUND_STATE_FIELDS " == *" $key "* && "$value" != *$'\n'* && "$value" != *:* ]] || return 1
    assignments+="${separator}${key}=${value}"
    separator=$'\034'
  done
  tmp="${file}.tmp.$$"
  awk -v assignments="$assignments" '
    BEGIN {
      count = split(assignments, pairs, "\034")
      for (i = 1; i <= count; i++) {
        split_at = index(pairs[i], "=")
        key = substr(pairs[i], 1, split_at - 1)
        values[key] = substr(pairs[i], split_at + 1)
        required[key] = 1
      }
    }
    {
      split_at = index($0, ":")
      key = substr($0, 1, split_at - 1)
      if (key in required) {
        print key ": \"" values[key] "\""
        found[key] = 1
        next
      }
      print
    }
    END {
      for (key in required) if (!(key in found)) exit 2
    }
  ' "$file" >"$tmp" || {
    rm -f "$tmp"
    return 1
  }
  mv "$tmp" "$file"
}

update_field() { update_fields "$@"; }

repository_fingerprint() {
  local root="$1" mode="$2" excluded="${3:-}" excluded_rel="" excluded_dir head tree tracked untracked
  if [[ -n "$excluded" ]]; then
    excluded_dir=$(resolve_directory "$(dirname "$excluded")") || return 1
    excluded="$excluded_dir/$(basename "$excluded")"
  fi
  [[ -z "$excluded" || "$excluded" != "$root"/* ]] || excluded_rel=${excluded#"$root"/}
  if [[ "$mode" == git ]]; then
    head=$(git -C "$root" rev-parse HEAD) || return 1
    tree=$(git -C "$root" write-tree) || return 1
    if [[ -n "$excluded_rel" ]]; then
      tracked=$(git -C "$root" diff --binary HEAD -- . ":(exclude)$excluded_rel" | sha256_stream) || return 1
    else
      tracked=$(git -C "$root" diff --binary HEAD | sha256_stream) || return 1
    fi
    untracked=$(git -C "$root" ls-files --others --exclude-standard -z | while IFS= read -r -d '' path; do
      [[ "$path" == .claude/lean-refactor.* || "$path" == "$excluded_rel" ]] && continue
      printf '%s\0' "$path"
      sha256_file "$root/$path"
    done | sha256_stream) || return 1
    canonical_digest "$head" "$tree" "$tracked" "$untracked"
  else
    (cd "$root" && { find . -type f ! -path './.claude/lean-refactor.*' -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' path; do
      [[ "$root/${path#./}" == "$excluded" ]] && continue
      printf '%s\0' "$path"
      sha256_file "$path"
    done; } | sha256_stream)
  fi
}

validate_artifact() {
  local file="$1" path_field="$2" hash_field="$3" path
  path=$(parse_field "$file" "$path_field")
  [[ "$path" == /* && -f "$path" && "$(sha256_file "$path")" == "$(parse_field "$file" "$hash_field")" ]]
}
validate_wave() {
  local file="$1"
  [[ "$(parse_field "$file" expected_wave_status)" == complete ]] && validate_artifact "$file" expected_wave_manifest expected_wave_manifest_hash
}

approval_digest_for_state() {
  local file="$1"
  canonical_digest "$(parse_field "$file" session_id)" "$(parse_field "$file" scope_path)" "$(parse_field "$file" audit_file)" "$(parse_field "$file" approver)" "$(parse_field "$file" approval_conditions)" "$(parse_field "$file" approved_findings)" "$(parse_field "$file" approved_tier)" "$(parse_field "$file" approval_exclusions)" "$(parse_field "$file" approval_recorded_at)" "$(parse_field "$file" repository_fingerprint)" "$(parse_field "$file" baseline_result_hash)" "$(parse_field "$file" reference_inventory_hash)" "$(parse_field "$file" evidence_hash)" "$(parse_field "$file" classification_hash)" "$(parse_field "$file" boundary_diff_hash)" "$(parse_field "$file" state_impact_hash)" "$(parse_field "$file" external_impact_hash)"
}

validate_approval_envelope() {
  local file="$1" key expected
  validate_state "$file" || return 1
  [[ "$(parse_field "$file" approval_status)" == approved ]] || return 1
  for key in audit_file audit_hash approval_digest approval_recorded_at approver approved_findings approved_tier repository_fingerprint baseline_result_artifact baseline_result_hash reference_inventory_artifact reference_inventory_hash evidence_artifact evidence_hash classification_artifact classification_hash boundary_diff_artifact boundary_diff_hash state_impact_artifact state_impact_hash external_impact_artifact external_impact_hash; do [[ -n "$(parse_field "$file" "$key")" ]] || return 1; done
  [[ "$(parse_field "$file" audit_file)" == /* && -f "$(parse_field "$file" audit_file)" ]] || return 1
  validate_artifact "$file" baseline_result_artifact baseline_result_hash || return 1
  validate_artifact "$file" reference_inventory_artifact reference_inventory_hash || return 1
  validate_artifact "$file" evidence_artifact evidence_hash || return 1
  validate_artifact "$file" classification_artifact classification_hash || return 1
  validate_artifact "$file" boundary_diff_artifact boundary_diff_hash || return 1
  validate_artifact "$file" state_impact_artifact state_impact_hash || return 1
  validate_artifact "$file" external_impact_artifact external_impact_hash || return 1
  expected=$(approval_digest_for_state "$file") || return 1
  [[ "$expected" == "$(parse_field "$file" approval_digest)" ]]
}

validate_approval() {
  local file="$1" root mode
  validate_approval_envelope "$file" || return 1
  root=$(parse_field "$file" root_path)
  mode=$(parse_field "$file" mode)
  [[ "$(repository_fingerprint "$root" "$mode" "$(parse_field "$file" audit_file)")" == "$(parse_field "$file" repository_fingerprint)" ]]
}

revoke_approval() {
  local file="$1"
  update_fields "$file" approval_status revoked approval_digest ""
}

increment_failure() {
  local file="$1" message="$2" count
  validate_state "$file" || return 1
  count=$(parse_field "$file" failure_count)
  update_fields "$file" failure_count "$((count + 1))" last_failure "$message"
}

record_corrupt_failure() {
  local file="$1" message="$2" evidence count=0 tmp
  acquire_state_lock "$file" || return 1
  evidence="${file}.failure"
  [[ -f "$evidence" ]] && count=$(parse_field "$evidence" failure_count)
  [[ "$count" =~ ^[0-9]+$ ]] || count=0
  tmp="${evidence}.tmp.$$"
  cat >"$tmp" <<EOF
---
failure_count: "$((count + 1))"
last_failure: "$message"
state_path: "$file"
recorded_at: "$(date -u +%Y-%m-%dT%H%M%SZ)"
---
EOF
  mv "$tmp" "$evidence"
  release_state_lock
}

audit_field() { sed -n 's/^compound_'"$2"':[[:space:]]*//p' "$1" | tail -n 1; }
validate_terminal_audit() {
  local file="$1" marker="$2" audit current previous approval_required
  validate_state "$file" || return 1
  audit=$(parse_field "$file" audit_file)
  [[ "$audit" == /* && -f "$audit" ]] || return 1
  [[ "$(sha256_file "$audit")" == "$(parse_field "$file" audit_hash)" ]] || return 1
  [[ "$(audit_field "$audit" iteration)" == "$(parse_field "$file" iteration)" ]] || return 1
  validate_wave "$file" || return 1
  [[ "$(audit_field "$audit" verification)" == complete && "$(audit_field "$audit" expected_wave_status)" == "$(parse_field "$file" expected_wave_status)" ]] || return 1
  [[ "$(audit_field "$audit" expected_wave_manifest_hash)" == "$(parse_field "$file" expected_wave_manifest_hash)" ]] || return 1
  current=$(audit_field "$audit" current_signature)
  previous=$(audit_field "$audit" previous_signature)
  [[ -n "$current" && "$current" == "$(parse_field "$file" current_signature)" ]] || return 1
  approval_required=$(audit_field "$audit" approval_required)
  [[ "$approval_required" =~ ^(yes|no)$ ]] || return 1
  [[ "$approval_required" == no ]] || validate_approval_envelope "$file" || return 1
  if [[ "$marker" == complete ]]; then
    [[ "$(audit_field "$audit" repair_ready_count)" == 0 ]] || return 1
  else
    [[ -n "$previous" && "$current" == "$previous" && "$previous" == "$(parse_field "$file" previous_signature)" ]] || return 1
  fi
}
