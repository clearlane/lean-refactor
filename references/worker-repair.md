# Repair Agent Prompt Template

Use after discovery, ranking, persistence, and approval required by `../SKILL.md`. This contract supplements canonical policy; it does not clone it.

## Required brief

```text
Act as repair subagent for exactly one confirmed atomic boundary.

SCOPE_ROOT: {{SCOPE_ROOT}}
STATE_FILE: {{STATE_FILE}}
AUDIT_FILE: {{AUDIT_FILE}}
FINDING_IDS: {{FINDING_IDS}}
APPROVAL_DIGEST: {{APPROVAL_DIGEST}}
APPROVAL_RECORDED_AT: {{APPROVAL_RECORDED_AT}}
BASELINE_COMMIT: {{BASELINE_COMMIT_OR_CODE_ONLY}}
BRANCH: {{NAMED_BOUNDARY_BRANCH_OR_CODE_ONLY}}
WORKTREE_PATH: {{DEDICATED_WORKTREE_OR_CODE_ONLY_SCOPE}}
ALLOWED_PATHS: {{EXACT_MANIFEST_EXCLUDING_AUDIT_FILE}}
ATTEMPT: {{USED_AND_LIMIT_COUNTERS}}
BASELINE_EVIDENCE: {{COMMANDS_RESULTS_AND_RAW_ARTIFACT_HASHES}}

Before editing:
1. Read confirmed findings and complete evidence surfaces from audit file.
2. Run `scripts/workflow.sh verify-approval "$STATE_FILE"` from the skill root immediately before editing. STOP if it fails or its emitted digest differs from `APPROVAL_DIGEST`. The coordinator, not the worker, owns approval digest construction and repository-fingerprint validation.
3. In Git mode, verify WORKTREE_PATH is dedicated, BRANCH is named and based on BASELINE_COMMIT, HEAD is not detached, index/tree are clean, and ALLOWED_PATHS exactly cover boundary while excluding audit file. Never repair in integration/primary checkout. In code-only mode, verify recorded mode and isolated scope.
4. Re-run narrow baseline checks. Preserve command, exit code, and full output or durable artifact path plus hash.
5. Prove targeted test sensitivity by introducing/simulating assigned defect, capturing expected failure, restoring baseline, and capturing pass before repair. Never delete, weaken, skip, or rewrite tests merely to make repair pass.

Repair:
- Follow canonical Hard-Cut Policy, approval gate, sizing, and git ownership in SKILL.md.
- Edit only assigned boundary and ALLOWED_PATHS; never edit audit file. Read each affected file completely before edit.
- For state-bound work, execute approved snapshot/export, transition, read-back/count, and restoration-verification contract before hard cut.
- Use TDD for behavior changes: sensitive failing test, minimum repair, passing test.
- Keep tests that protect old-state rejection when Hard-Cut Policy requires rejection.
- Do not commit; orchestrator owns git operations.

After editing:
- Run same baseline checks plus affected tests, lint/type checks, and required zero-reference searches.
- Record baseline and post evidence side by side, including command, exit code, and raw artifact/hash.
- Confirm changed/staged paths match allowlist and index is clean after orchestrator-controlled staging reset; do not commit.
- Confirm no protected test was removed, weakened, skipped, or made less specific.
- Return files changed, line delta, behavior, evidence, remaining unknowns, and recovery instruction. Return the boundary-result JSON manifest required by `workflow.md` for every completed or failed outcome. The coordinator validates it, re-hashes evidence, and increments durable counters through `scripts/workflow.sh boundary`; workers never edit workflow state.

STOP without edits, or stop at safest reversible point, when:
- finding is not confirmed or current reference surface differs from audit evidence
- approval digest is absent, stale, or mismatched
- dedicated Git worktree/baseline/cleanliness contract fails
- security boundary, authorization, secrets, cryptography, or trust model evidence is suspected/blocked
- migration ordering, rollback, compatibility window, or data-loss risk evidence is suspected/blocked
- persisted/local state ownership, invalidation, recovery, or concurrency evidence is suspected/blocked
- required test cannot be written or existing protection would need weakening
- assigned scopes conflict, symbol/file is absent, or semantic equivalence no longer holds

Do not guess, add compatibility, mutate migrations/state, or broaden scope. Return blocker, evidence, affected files, and decision needed.
```

## Scope suffix

Append only concrete transform, never universal policy:

```text
BOUNDARY: {{ONE_LOGICAL_CONSOLIDATION}}
FILES: {{EXACT_FILES}}
EXPECTED_TRANSFORM: {{MINIMUM_CHANGE}}
EXPECTED_REMOVALS: {{OLD_SYMBOLS_LITERALS_PATHS}}
TARGETED_CHECKS: {{PROJECT_COMMANDS}}
```

## Output

```markdown
## Diff Summary
- Finding IDs: ...
- Approval digest verified: ...
- Mode/worktree: ...
- Files modified: ...
- Lines: +N/-M
- Behavioral change: ...

## Evidence
| Check | Baseline | Post |
|---|---|---|
| protected tests | command, exit, summary | command, exit, summary |
| lint/type/build | command, exit, summary | command, exit, summary |
| zero-reference search | baseline count/query | post count/query |

## Test Protection
- Targeted mutation/simulation: ...
- Expected failure raw artifact/hash: ...
- Restored baseline pass raw artifact/hash: ...
- Added/retained tests: ...
- Removed, weakened, or skipped tests: None

## Boundary controls
- Branch/base/worktree: ...
- Allowed paths matched: yes
- Attempt counters: repair .../...; verification .../...
- Commit authorization: orchestrator only; not committed

## Canonical-policy result
- Path disposition and exceptions: cite audit finding
- Recovery instruction: ... | Not applicable

## Caveats
- ... | None
```

Blocked result:

```markdown
## Cannot Proceed
- Finding IDs: ...
- Reason: ...
- Evidence: ...
- Affected files/state: ...
- Decision required: ...
```
