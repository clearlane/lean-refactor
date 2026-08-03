# Iterative Loop — Runtime Contract

Canonical workflow and marker meaning live in `../SKILL.md`. Executable schema, validation, digests, root resolution, failure evidence, and audit checks live in `../scripts/state.sh`; this document names that contract without copying its field list.

## Root and setup

`scope_path` resolves first. Git mode persists absolute `git rev-parse --show-toplevel`; explicit `--code-only` persists resolved scope as root. Every path derives from persisted root, never caller CWD.

Iterative Git mode is strictly clean-only. The coordinator's initialization adapter checks tracked and untracked dirt before creating directories or state. Dirty setup exits nonzero; it never stashes, commits, resets, or cleans. Code-only mode requires explicit opt-in.

```text
scripts/workflow.sh init <SCOPE_PATH> [--depth review|refactor] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

Setup calls `write_state` from `state.sh`. `LEAN_STATE_FIELDS` is canonical ordered schema. State path is `<root_path>/<state-dir>/lean-refactor.<session_id>.local.md`, where `<state-dir>` defaults to `.claude` and hosts override it with `LEAN_REFACTOR_STATE_DIR` (one safe path segment). The same value is excluded from every repository fingerprint, so changing it mid-run orphans existing state. Format is flat frontmatter, one colon/newline-free scalar per field. `schema_version` rejects stale layouts.

Schema covers identity/counters/mode/paths/baseline; the coordinator `phase`; audit path and content hash; approval status/digest/time/approver/conditions/findings/tier/exclusions; live repository fingerprint; artifact path/hash pairs for baseline result, reference inventory, evidence, classification, boundary diff, state impact, and external impact; discovery-checkpoint and boundary-ledger path/hash pairs; current/previous finding signatures; expected-wave manifest path/hash/status; hook failure count/limit/evidence. Approved state requires every approval-bound value except exclusions and conditions. Validation recomputes repository fingerprint and every source artifact hash; copied state hashes cannot establish freshness.

`depth` is validated at initialization as `review` or `refactor`, defaults to `refactor`, and is immutable for the life of a run. It is orthogonal to `mode`, which selects git or code-only backing. A `review` run must keep `approval_status: pending`; state validation rejects any other combination.

`phase` is the coordinator's durable transition owner. Both depths share `discovery -> prior_art -> layer_scans -> synthesis -> audit_ready`. From `audit_ready`, a `review` run advances to terminal `reported` through `scripts/workflow.sh report`, and a `refactor` run advances `approved -> repair -> verification -> rediscovery`. Mutating transitions acquire an atomic per-session lock, revalidate after acquisition, fail retryably with exit `75` on live contention, reclaim a lock whose recorded owner process no longer exists, and use one same-directory atomic state replacement. Record each discovery artifact through `scripts/workflow.sh discovery`; the adapter enforces prior art before layer scans and synthesis only after the complete layer-report artifact exists. Approval and zero-finding conclusion require `audit_ready`; boundary results and finalization are valid only from approved-or-later phases; continuation returns the session to `discovery`. Approver identity and any approval conditions are bound into the approval digest, so changing either invalidates approval.

When discovery or rediscovery proves there are zero repair-ready findings, run `scripts/workflow.sh conclude-discovery <STATE> <AUDIT> --manifest FILE --current-signature SHA256 [--previous-signature SHA256] --repair-ready-count 0`. It binds the discovery evidence manifest, appends the current iteration's terminal audit fields, and enables the complete marker without manufacturing a new approval. Nonzero discovery cannot use this transition.

The coordinator records each repair or verification outcome through `scripts/workflow.sh boundary`. Its JSON ledger owns separate repair-attempt and verification-failure counters, each limited to `2`, separate repair and verification statuses, aggregate boundary status, and an append-only history of every evidence manifest/hash. Every repair outcome increments the repair-attempt counter; retryable or failed verification increments the verification-failure counter. Resume validation derives attempt sequences, counters, latest-result fields, stage statuses, and aggregate status from that history, rejecting impossible combinations. Exhaustion becomes terminal `blocked`, and a completed repair or verification stage cannot be submitted again. A boundary becomes `completed` only after both stages complete. The boundary-result adapter validates a JSON manifest containing boundary ID, the next durable stage-attempt number, result, branch/worktree, base/diff fingerprints, allowed and changed paths, commands/results, hashed evidence artifacts, blocker, and stale dependents. Manifest paths are single-use so recorded evidence remains immutable. Paths must be unique, safe repository-relative paths, and every changed path must be allowed. Completed results require at least one command, only zero exit codes, and no blocker; non-completed results require a blocker and hashed evidence. Validation re-hashes every historical manifest and referenced evidence before recording another result. Wave finalization requires every approved boundary to be `completed`; pending or blocked work cannot be represented as a successful wave. Workers receive the state path but never mutate workflow state themselves.

## Review terminal

A `depth=review` run never reaches approval. It terminates here:

```text
scripts/workflow.sh report <STATE> <AUDIT> --manifest FILE --current-signature SHA256 [--previous-signature SHA256] --finding-count N
```

It requires `depth=review`, phase `audit_ready`, a valid discovery ledger, and the exact audit artifact and hash recorded by the current iteration's audit checkpoint. It appends the terminal audit fields, binds the evidence manifest, and moves the run to `reported`. A finding count of zero is a valid published outcome, so an honest empty review is not forced through a convergence path built for repair. `scripts/workflow.sh approve` refuses a review run, which makes read-only a coordinator guarantee rather than an instruction.

## Approval

```text
scripts/workflow.sh approve <STATE> <AUDIT> --approver ID [--conditions TEXT] --findings IDS --tier N [--exclude IDS] \
  --baseline-result FILE --reference-inventory FILE --evidence FILE \
  --classification FILE --boundary-diff FILE --state-impact FILE \
  --external-impact FILE --wave-manifest FILE
```

Producer requires comma-separated stable finding IDs, absolute existing artifact paths, and approver identity. The audit must be the exact artifact and hash recorded by the current iteration's discovery audit checkpoint. Approved and excluded ID lists must each be unique and must not overlap. It initializes exactly the approved IDs as pending boundary-ledger entries, records artifact SHA-256 hashes, captures the live repository fingerprint, and atomically replaces ledger and state only after full validation. It records the expected wave as `pending`. Git fingerprint binds HEAD, index tree, tracked binary diff, and path/content hashes of untracked files; code-only mode binds sorted path/content hashes. Immediately before mutation, `validate_approval` recomputes the immutable approval sources and requires the live repository fingerprint to match. After an approved repair changes the repository, finalization uses `validate_approval_envelope`: it still verifies approval status, digest, audit path, and every approval-bound artifact hash, but does not mistake the expected repair diff for stale pre-mutation approval. Approval binds the audit path but not mutable audit content/hash. `sha256sum` is preferred; `shasum -a 256` is fallback.

## Wave finalization

```text
scripts/workflow.sh finalize <STATE> <AUDIT> --manifest FILE \
  --current-signature SHA256 [--previous-signature SHA256] \
  --repair-ready-count N --approval-required yes|no
```

Finalize only after repair and verification complete. Command requires pending state, unchanged approved manifest, and a valid immutable approval envelope; live repository freshness was consumed at the pre-mutation gate and is expected to differ after repair. It then atomically appends canonical machine fields and marks wave complete. Machine fields use exact `lean_<key>:` names. Records are append-only; parser uses last exact occurrence. No manual state edits are supported.

## Stop hook

The host hook is a thin event adapter: it parses hook JSON, identifies the exact session and last assistant output, then calls `scripts/workflow.sh advance`. The coordinator owns marker validation, failure limits, iteration increments, terminal cleanup, and the transition back to `discovery`. Continuation requires persisted `expected_wave_status=complete` and a current manifest hash matching the persisted path/hash. Hook infrastructure failure limit is `2`; it stops continuation and preserves evidence. Per-boundary repair and verification budgets live in the boundary ledger and default to `2` each.

Assistant marker alone has no authority. Audit must append machine-readable lines:

```text
lean_iteration: <current integer>
lean_repair_ready_count: <integer>
lean_verification: complete
lean_approval_required: yes|no
lean_current_signature: <stable SHA-256>
lean_previous_signature: <stable SHA-256 or empty>
lean_expected_wave_status: complete
lean_expected_wave_manifest_hash: <current manifest SHA-256>
```

`<lean-refactor-complete>` is accepted only when state/audit hashes and current iteration match, expected wave and verification are complete, repair-ready count is zero, current signature matches state, and approval validates when `approval_required: yes`.

`<lean-refactor-stuck>` is accepted only when same common checks pass and nonempty current/previous signatures are mechanically equal in both audit and state. Unsupported markers block continuation and preserve state.

Corrupt state fails closed. Hook leaves original untouched, atomically increments separate `<state>.failure` evidence, and emits blocking hook decision. It never converts corruption into completion.

## Cancellation

```text
scripts/workflow.sh cancel [--root <scope-or-root>] [SESSION_ID]
```

Root uses same Git-first, code-only fallback resolution. Cancellation joins the per-session mutation lock, revalidates after acquisition, and preserves busy or changed sessions for retry. Only valid matching state below exact resolved root is removed. Corrupt state and `.failure` evidence remain; source changes remain untouched.
