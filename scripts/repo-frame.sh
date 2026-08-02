#!/bin/bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: repo-frame.sh [ROOT] [--output FILE] [--init-codegraph] [--run-cpd]
                     [--cpd-min-lines N] [--cpd-min-tokens N]

Build a compact JSON repository frame for discovery workers. All accelerators
are optional. CodeGraph is not initialized or updated unless explicitly asked.
EOF
}

root=""
output=""
init_codegraph=no
run_cpd=no
cpd_min_lines=5
cpd_min_tokens=50
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ -n "${2:-}" ]] || {
        usage
        exit 64
      }
      output="$2"
      shift 2
      ;;
    --init-codegraph)
      init_codegraph=yes
      shift
      ;;
    --run-cpd)
      run_cpd=yes
      shift
      ;;
    --cpd-min-lines)
      [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || {
        usage
        exit 64
      }
      cpd_min_lines="$2"
      shift 2
      ;;
    --cpd-min-tokens)
      [[ "${2:-}" =~ ^[1-9][0-9]*$ ]] || {
        usage
        exit 64
      }
      cpd_min_tokens="$2"
      shift 2
      ;;
    --*)
      usage
      exit 64
      ;;
    *)
      [[ -z "$root" ]] || {
        usage
        exit 64
      }
      root="$1"
      shift
      ;;
  esac
done

root=${root:-"$(pwd)"}
root=$(cd "$root" 2>/dev/null && pwd -P) || {
  echo "Error: repository root is not a directory: $root" >&2
  exit 64
}
[[ -z "$output" || "$output" == /* ]] || output="$PWD/$output"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

tool_version() {
  case "$1" in
    codegraph) codegraph --version 2>/dev/null | head -n 1 ;;
    scc) scc --version 2>/dev/null | head -n 1 ;;
    cpd) cpd --version 2>/dev/null | head -n 1 ;;
    jscpd) jscpd --version 2>/dev/null | head -n 1 ;;
    ast-grep) ast-grep --version 2>/dev/null | head -n 1 ;;
    sg) sg --version 2>/dev/null | head -n 1 ;;
    rg) rg --version 2>/dev/null | head -n 1 ;;
  esac
}

for tool in codegraph scc cpd jscpd ast-grep sg rg; do
  if command -v "$tool" >/dev/null 2>&1; then
    jq -n --arg name "$tool" --arg path "$(command -v "$tool")" \
      --arg version "$(tool_version "$tool")" \
      '{name:$name, available:true, path:$path, version:$version}' >"$tmp/tool-$tool.json"
  else
    jq -n --arg name "$tool" '{name:$name, available:false, path:"", version:""}' >"$tmp/tool-$tool.json"
  fi
done
jq -s 'map({key:.name, value:del(.name)}) | from_entries' "$tmp"/tool-*.json >"$tmp/tools.json"

if command -v rg >/dev/null 2>&1; then
  (cd "$root" && rg --files -0 -g '!.git' -g '!.codegraph' 2>/dev/null || true) |
    jq -Rs 'split("\u0000") | map(select(length > 0))' >"$tmp/files.json"
else
  (cd "$root" && find . -type f ! -path './.git/*' ! -path './.codegraph/*' -print0) |
    jq -Rs 'split("\u0000") | map(select(length > 0) | sub("^\\./"; ""))' >"$tmp/files.json"
fi

codegraph_state=unavailable
printf '{}\n' >"$tmp/codegraph-status.json"
printf '[]\n' >"$tmp/codegraph-files.json"
if command -v codegraph >/dev/null 2>&1; then
  if [[ "$init_codegraph" == yes ]]; then
    if [[ -d "$root/.codegraph" ]]; then
      codegraph sync "$root" >/dev/null
    else
      codegraph init "$root" >/dev/null
    fi
  fi
  if codegraph status "$root" --json >"$tmp/codegraph-status.json" 2>/dev/null &&
    jq -e '.initialized == true and .index.state == "complete"' "$tmp/codegraph-status.json" >/dev/null; then
    if jq -e '
      (.pendingChanges.added // 0) == 0 and
      (.pendingChanges.modified // 0) == 0 and
      (.pendingChanges.removed // 0) == 0 and
      (.index.reindexRecommended // false) == false
    ' "$tmp/codegraph-status.json" >/dev/null; then
      codegraph_state=ready
      codegraph files --path "$root" --format flat --json >"$tmp/codegraph-files.json" 2>/dev/null || printf '[]\n' >"$tmp/codegraph-files.json"
    else
      codegraph_state=stale
    fi
  else
    codegraph_state=not-initialized
  fi
fi

printf 'null\n' >"$tmp/scc.json"
if command -v scc >/dev/null 2>&1; then
  scc --format json --min-gen --dryness "$root" >"$tmp/scc.json" 2>/dev/null || printf 'null\n' >"$tmp/scc.json"
fi

cpd_tool=""
command -v cpd >/dev/null 2>&1 && cpd_tool=cpd
[[ -n "$cpd_tool" ]] || ! command -v jscpd >/dev/null 2>&1 || cpd_tool=jscpd
printf 'null\n' >"$tmp/cpd.json"
cpd_command=""
if [[ "$run_cpd" == yes && -n "$cpd_tool" ]]; then
  mkdir -p "$tmp/cpd-output"
  cpd_command="$cpd_tool --min-lines $cpd_min_lines --min-tokens $cpd_min_tokens --reporters json --output <temporary> --silent --no-tips <root>"
  "$cpd_tool" --min-lines "$cpd_min_lines" --min-tokens "$cpd_min_tokens" \
    --reporters json --output "$tmp/cpd-output" --silent --no-tips "$root" >/dev/null 2>&1 || true
  cpd_report=$(find "$tmp/cpd-output" -type f -name '*.json' -print -quit)
  [[ -z "$cpd_report" ]] || cp "$cpd_report" "$tmp/cpd.json"
fi

# Structural queries are scope-specific. Advertise ast-grep here; layer
# workers execute queries with recorded provenance.
jq -n \
  --arg root "$root" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H%M%SZ)" \
  --arg codegraph_state "$codegraph_state" \
  --arg cpd_tool "$cpd_tool" \
  --arg cpd_command "$cpd_command" \
  --slurpfile tools "$tmp/tools.json" \
  --slurpfile files "$tmp/files.json" \
  --slurpfile cg_status "$tmp/codegraph-status.json" \
  --slurpfile cg_files "$tmp/codegraph-files.json" \
  --slurpfile scc "$tmp/scc.json" \
  --slurpfile cpd "$tmp/cpd.json" '
  {
    schema_version: 1,
    root: $root,
    generated_at: $generated_at,
    tools: $tools[0],
    inventory: {
      file_count: ($files[0] | length),
      files: $files[0],
      scc: $scc[0],
      cpd: {
        tool: $cpd_tool,
        executed: ($cpd_command != ""),
        command: $cpd_command,
        report: $cpd[0]
      }
    },
    codegraph: {
      state: $codegraph_state,
      status: $cg_status[0],
      files: $cg_files[0],
      guidance: (if $codegraph_state == "ready" then
        "Use query/callers/callees/impact/affected with --json for supported languages; retain rg and persisted-state searches for completeness."
      else
        (if $codegraph_state == "stale" then
          "CodeGraph has pending changes or needs reindexing. Do not query it as evidence; use fallbacks or explicitly authorize --init-codegraph to sync it."
        else
          "CodeGraph is optional. Use deterministic fallbacks unless initialization was explicitly authorized."
        end)
      end)
    }
  }' >"$tmp/frame.json"

schema="$(cd "$(dirname "${BASH_SOURCE[0]}")/../schemas" && pwd)/repo-frame.schema.json"
if [[ "${LEAN_REFACTOR_STRICT_SCHEMA:-0}" == 1 ]] && command -v check-jsonschema >/dev/null 2>&1; then
  check-jsonschema --schemafile "$schema" "$tmp/frame.json" >/dev/null
else
  jq -e '.schema_version == 1 and (.root | startswith("/")) and (.inventory.files | type == "array")' "$tmp/frame.json" >/dev/null
fi

if [[ -n "$output" ]]; then
  mkdir -p "$(dirname "$output")"
  cp "$tmp/frame.json" "$output"
  printf '%s\n' "$output"
else
  cat "$tmp/frame.json"
fi
