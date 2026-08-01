# Iterative Loop — Runtime Contract

Canonical workflow and marker meaning live in `../SKILL.md`. Executable schema, validation, digests, root resolution, failure evidence, and audit checks live in `../scripts/lib.sh`; this document names that contract without copying its field list.

## Root and setup

`scope_path` resolves first. Git mode persists absolute `git rev-parse --show-toplevel`; explicit `--code-only` persists resolved scope as root. Every path derives from persisted root, never caller CWD.

Iterative Git mode is strictly clean-only. `setup-loop.sh` checks tracked and untracked dirt before creating directories or state. Dirty setup exits nonzero; it never stashes, commits, resets, or cleans. Code-only mode requires explicit opt-in.

```text
scripts/setup-loop.sh <SCOPE_PATH> [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

Setup calls `write_state` from `lib.sh`. `COMPOUND_STATE_FIELDS` is canonical ordered schema. State path is `<root_path>/.claude/lean-refactor.<session_id>.local.md`; format is flat frontmatter, one colon/newline-free scalar per field. `schema_version` rejects stale layouts.

Schema covers identity/counters/mode/paths/baseline; audit path and content hash; approval status/digest/time/findings/tier/exclusions; live repository fingerprint; artifact path/hash pairs for baseline result, reference inventory, evidence, classification, boundary diff, state impact, and external impact; current/previous finding signatures; expected-wave manifest path/hash/status; failure count/limit/evidence. Approved state requires every approval-bound value except exclusions. Validation recomputes repository fingerprint and every source artifact hash; copied state hashes cannot establish freshness.

## Approval

```text
scripts/record-approval.sh <STATE> <AUDIT> --findings IDS --tier N [--exclude IDS] \
  --baseline-result FILE --reference-inventory FILE --evidence FILE \
  --classification FILE --boundary-diff FILE --state-impact FILE \
  --external-impact FILE --wave-manifest FILE
```

Producer requires absolute existing artifact paths, records their SHA-256 hashes, captures live repository fingerprint, and atomically replaces state only after full validation. It records the expected wave as `pending`. Git fingerprint binds HEAD, index tree, tracked binary diff, and path/content hashes of untracked files; code-only mode binds sorted path/content hashes. `validate_approval` recomputes all immutable approval sources. Approval binds the audit path but not mutable audit content/hash; execution-log and machine-field appends therefore preserve approval, while any approval-bound artifact or repository change makes it stale. `sha256sum` is preferred; `shasum -a 256` is fallback.

## Wave finalization

```text
scripts/record-wave.sh <STATE> <AUDIT> --manifest FILE \
  --current-signature SHA256 [--previous-signature SHA256] \
  --repair-ready-count N --approval-required yes|no
```

Finalize only after repair and verification complete. Command requires pending state, unchanged approved manifest, and fresh approval; then atomically appends canonical machine fields and marks wave complete. Machine fields use exact `compound_<key>:` names. Records are append-only; parser uses last exact occurrence. No manual state edits are supported.

## Stop hook

Hook reads JSON stdin, identifies exact session from transcript, then validates state. Continuation requires persisted `expected_wave_status=complete` and a current manifest hash matching persisted path/hash before incrementing iteration. Hook infrastructure failure limit is `2`; it stops continuation and preserves evidence. Per-boundary repair and verification budgets remain separate audit counters, also defaulting to `2` each.

Assistant marker alone has no authority. Audit must append machine-readable lines:

```text
compound_iteration: <current integer>
compound_repair_ready_count: <integer>
compound_verification: complete
compound_approval_required: yes|no
compound_current_signature: <stable SHA-256>
compound_previous_signature: <stable SHA-256 or empty>
compound_expected_wave_status: complete
compound_expected_wave_manifest_hash: <current manifest SHA-256>
```

`<lean-refactor-complete>` is accepted only when state/audit hashes and current iteration match, expected wave and verification are complete, repair-ready count is zero, current signature matches state, and approval validates when `approval_required: yes`.

`<lean-refactor-stuck>` is accepted only when same common checks pass and nonempty current/previous signatures are mechanically equal in both audit and state. Unsupported markers block continuation and preserve state.

Corrupt state fails closed. Hook leaves original untouched, atomically increments separate `<state>.failure` evidence, and emits blocking hook decision. It never converts corruption into completion.

## Cancellation

```text
scripts/cancel-loop.sh [--root <scope-or-root>] [SESSION_ID]
```

Root uses same Git-first, code-only fallback resolution. Only valid matching state below exact resolved root is removed. Corrupt state and `.failure` evidence remain; source changes remain untouched.
