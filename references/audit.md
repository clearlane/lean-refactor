# Audit File Template

Create an audit scaffold at `docs/audits/<YYYY-MM-DD>-lean-refactor-<scope>.md` using this structure, then fill it with consolidated findings. The file is the persistent SSOT for the run — it survives context-window resets and lets the user review async.

## Template

Fields below record evidence required by `SKILL.md` § Safety and Evidence Invariants; that section governs conflicts and interpretation.

```markdown
---
date: YYYY-MM-DD
scope: <plugins/foo or whole-repo>
command: /lean-refactor <scope>
status: pending-approval | in-progress | partial | complete | deferred
depth: review | refactor
repository_mode: git-backed | non-git-code-only
persistence: durable:<path> | blocked:<reason>
baseline_fingerprint: <HEAD/tree or snapshot hashes>
dirty_tree_decision: clean | user-stashed-before-init | user-committed-before-init | code-only-explicit
agents_dispatched:
  - prior-art-researcher # completed first
  - <parallel layer reviewers>
  - cross-cutting-synthesis # dispatched after layer reports
---

# Lean Refactor — <scope>

## Summary

- Total findings: N
- LOC duplicated (estimated): X
- Expected reduction: Y
- High-drift hazards (≥2): Z
- Latent bugs surfaced: W
- Evidence: confirmed N | suspected N | blocked N
- Severity: P0 N | P1 N | P2 N | P3 N
- Excluded security controls: N
- State-bound findings: N

## Coverage gaps

A reader must be able to see the shape of what was not examined. This section is never omitted; when nothing was blocked, say so explicitly.

- Blocked lenses: `<lens — why it could not run>` | none
- Withheld claims: `<suspected/blocked finding IDs and the evidence each still needs>` | none
- Unqueryable stores or surfaces: `<what, and what stopped the inspection>` | none

## Depth disposition

- Depth: review | refactor
- Severity floor published: `<P0–P3>` | n/a
- Report path/hash: `<path>` / `<SHA-256>` | n/a
- Approval/repair prohibited: yes (review) | no (refactor)

## Approval record

- Approver / timestamp: <identity> / <ISO-8601>
- Approved tier and finding IDs/boundaries: <exact list>
- Fingerprint: <HEAD/tree or snapshot hashes>
- Conditions: <none or exact conditions>
- Freshness: valid | expired — <changed input>

## Baseline verification

| Command | Environment | Exit/result | Timestamp |
|---|---|---|---|
| `<exact command>` | `<cwd, versions, relevant env>` | `<result>` | `<ISO-8601>` |

## Reference-surface inventory

| Surface | Exact query/root/filters | Exclusions | Count/locations | Stores/files + tool/version/timestamp | Raw evidence |
|---|---|---|---|---|---|
| `<including dynamic/indirect identifiers and persisted stores>` | `<reproducible>` | `<explicit>` | `<count/locations>` | `<complete>` | `<embedded output or durable path + SHA-256>` |

## Already-consolidated baseline (recent SSOT commits, do NOT redo)

- `<hash>` — <subject>
- `<hash>` — <subject>
- (output of `git log --oneline -30 --grep="refactor\|SSOT\|consolidate\|DRY"`)

## Tier 1 — trivial effort, high compound (auto-execute candidates)

| # | Finding | Sites | Hazard | Effort | Lev | Status |
|---|---|---|---|---|---|---|
| 1.A | <one-line title> | <K> | <0–3> | 1 | <K×H/E> | pending |
| ... |

### 1.A — <one-line title>

**Sites affected** (literal count: K):
- `path/file1.ext:line`
- `path/file2.ext:line`
- ...

**Current** (excerpt):
```<lang>
<≤8 lines of duplicated code>
```

**Proposed SSOT**: <where it should live + form (function / class / constant / utility)>

**Score justification**:
- **Severity**: `<P0–P3>` — `<impact rationale, independent of effort>`
- **Sites affected**: `<K>` — `<literal-count rationale>`
- **Effort**: `<1–4>` — `<estimate rationale>`
- **Drift hazard**: `<0–3>` — `<evidence rationale>`
- **Leverage/tier**: `<K × H / E; tier>` — `<threshold rationale, or untiered because not compound>`
- **Corroborating lenses**: `<every lens that independently observed this defect>`

**Notes**: <caveats>

**Evidence**: confirmed | suspected | blocked
- **Full provenance**: `<query, root, filters, exclusions, count, inspected files/stores, tool/version, timestamp>`
- **Raw evidence**: `<embedded full output or durable artifact path + SHA-256>`
- **Semantic equivalence**: `<inputs, outputs, side effects, order, errors, lifecycle, security, state, consumers>`
- **Conflict reconciliation**: `<reports, disagreement, decision, supporting evidence or none>`
- **Blocker/needed evidence**: `<required when not confirmed; unqueryable store => blocked>`

**Change classifications**:
- **Finding**: code-only | state-bound
- **Special surface**: security-control | applied migration | new migration | deletion | external | none
- `<path or symbol>` — canonical | legacy | temporary compatibility | orchestration fallback

**Canonicality proof**:
- Proposed owner: `<symbol/path>`
- Owned behavior: `<scope>`
- Consumers migrated: `<complete list>`
- Competing writers/definitions: `<zero or locations>`

**Boundary controls**:
- Worktree/isolation path + base fingerprint: `<path>` / `<fingerprint>`
- Branch/worktree/base: `<named branch; never detached>` / `<path>` / `<fingerprint>`
- Allowed-path manifest: `<exact paths; excludes audit file>`
- Dependency order: `<predecessors>`
- Commit authorization: `<approver, approved boundary/diff fingerprint, status>`
- Failure budget/counters: repair `<used>/<limit>`; verification `<used>/<limit>`
- Failed-wave manifest: `<attempt, branch/worktree, fingerprints, allowed/changed paths, commands, artifact hashes, status, blocker, stale dependents or n/a>`
- Test protection/mutation sensitivity: `<targeted mutation, expected failure artifact, restored-pass artifact>`
- State snapshot/transition/restoration: `<export path+hash; transition/read-back/counts; restoration command+verified result or n/a>`
- Review required: yes | no — `<reason>`

**Legacy-path disposition**: removed, with zero remaining references | temporary compatibility explicitly approved

<!-- Include the following block only when temporary compatibility was explicitly approved. No compatibility is the default. -->
**Temporary compatibility exception**:
- **Reason**: <why transition support is required>
- **Canonical insufficiency**: <why the canonical path cannot yet serve every required consumer>
- **Exact deletion criteria**: <observable conditions that require removing compatibility>
- **Tracking ADR/task**: `<ADR path or task ID created in the same diff>`

**Verification evidence**:
- Pre/post identical commands: `<command>` — baseline `<result>`; post `<result>`
- Negative zero-reference search: `<command + zero result>`
- Positive control: `<same command/scope against canonical symbol + nonzero result>`
- Deletion review: `<behavior, side effects, observability, docs, tests, recovery, external consumers>`
- Test changes: none | explicitly approved `<test, approver, reason>`
- Pre-commit review: `{ reviewer_identity, timestamp, diff_fingerprint, checklist: {canonicality, tests, deletion, migration, state, external, evidence}, findings, verdict }`

**Status**: pending | in-progress | resolved by `<hash>` | deferred | blocked — `<reason>`

---

## Tier 2 — small effort, high compound (confirm)

| # | Finding | Sites | Hazard | Effort | Lev | Status |
|---|---|---|---|---|---|---|
| ... |

### 2.A — ...
...

## Tier 3 — medium effort, high payoff (confirm + plan)

...

## Tier 4 — defer to dedicated planning

Findings that require larger structural decisions or design discussion. Each entry should have enough context for a dedicated planning workflow to take it forward.

- 4.A: <title> — <one-paragraph reason for deferral>

## Already well-consolidated (do NOT redo)

(Bullet list of SSOTs that ARE properly in place — captured from agents' "already well-consolidated" tally so future runs skip them.)

## Machine lifecycle records

Append records only through `scripts/workflow.sh finalize`. Never rewrite older records. Parser accepts exact `lean_<key>:` names and uses last exact duplicate.

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

## Iteration N — finding signature

Sorted normalized IDs of every finding discovered this iteration, one per line.
Normalized ID format (from `workflow.md`): `<relative-path>:<primary-symbol-or-literal>:<finding-kind>`,
lowercased, no line numbers. Append a new section per iteration; never rewrite an
earlier one — the previous section is the only surviving record of the prior
iteration once context resets.

```
lib/helpers.ext:select_pair:unadopted-helper
templates/card.tmpl:tag-list-fragment:missing-partial
components/wrapper.ext:tags:enum-drift
```

Compare this section against `## Iteration N-1 — finding signature`. Identical
sorted sets mean no progress — emit `<lean-refactor-stuck>`.

## Execution log

- YYYY-MM-DD HH:MM — Mode, fingerprint, and dirty-tree decision recorded
- YYYY-MM-DD HH:MM — Prior-art report completed
- YYYY-MM-DD HH:MM — Layer agents dispatched in parallel
- YYYY-MM-DD HH:MM — Cross-cutting synthesis dispatched after reports
- YYYY-MM-DD HH:MM — Exhaustive audit written and recorded
- YYYY-MM-DD HH:MM — Approval persisted for `<IDs>` at `<fingerprint>`
- YYYY-MM-DD HH:MM — Boundary worktrees created: `<paths>`
- YYYY-MM-DD HH:MM — Commits landed: `<hashes>`
- YYYY-MM-DD HH:MM — Learning-capture capability recorded patterns in `docs/solutions/<file>.md`
```

## Tips

- **Title the defect, not the activity** — `Orphaned script has no inbound reference` tells the reader what is wrong; `Reviewed the scripts directory` does not. Two lenses observing one defect must produce titles close enough to merge, so name the defect and its location rather than the route taken to it.
- **Score severity and leverage on every finding** — they answer different questions and a run needs both. A single-site `P0` is untiered and still leads the report.
- **Status field per finding** — keep the audit file in sync as repair agents land. Mark `resolved by <hash>` so the audit becomes a permanent index from "drift surface" to "commit that closed it".
- **Legacy-path disposition per finding** — record complete removal by default. Include the temporary compatibility exception block only after explicit approval, with all four temporary-compatibility fields required by the Safety and Evidence Invariants and its ADR/task added in the same diff.
- **Leverage column in tables** — surfaces the formula at a glance for the user during the approval gate.
- **Worked excerpts under each finding** — the orchestrator's value is the synthesis; the agents supply raw observations. Don't lose them.
- **Tier 4 separate section** — these escalate to dedicated planning; keep them visible but separate so a future planning workflow can read just that section.
- **Execution log** — append-only timeline. Useful when the run spans multiple sessions.
