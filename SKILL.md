---
name: lean-refactor
description: Finds and fixes compounding SSOT/DRY opportunities through evidence-gated discovery, isolated repairs, and canonical hard cuts. Triggers on lean refactor, DRY sweep, hard cut, remove legacy paths, consolidate codebase, or fix everything compound. Not for single-file refactors, scoped bug fixes, net-new features, or cleanup limited to recent changes.
---

# Lean SSOT Refactor

Surface and eliminate SSOT (Single Source of Truth) and DRY violations across an entire codebase, prioritising **compound** opportunities — places where one consolidation ripples improvements across many call sites, files, or modules.

The skill uses an executable lifecycle coordinator for durable phase, approval, boundary, retry, and resume state. Discovery and repair may fan out through specialised workers; findings and evidence persist outside conversation context.

## Coordinator Entry

For mutating or resumable runs, invoke `scripts/workflow.sh init [SCOPE] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]`. Keep the returned state path and use only the coordinator commands `approve`, `verify-approval`, `boundary`, `finalize`, `conclude-discovery`, `status`, and `cancel` for workflow transitions. The scripts validate transition order and own mutable workflow state; workers return evidence and never edit it. Use `conclude-discovery` only when verified rediscovery has zero repair-ready findings; it creates the audit-backed evidence required for `<lean-refactor-complete>`.

Read `references/methodology.md` for discovery through integration procedure, `references/iterative-loop.md` for state and resume contracts, and `references/repair-agent-prompt.md` when delegating one approved atomic repair.

## Prerequisites

This skill is designed around the `compound-engineering` plugin, which supplies the `ce-*` subagents and the `/ce-*` slash commands referenced throughout.

`jq` must be installed and available on `PATH`; the Stop hook uses it to read Claude Code hook input and JSONL transcripts.

Verify plugin availability before Phase 0: run `/plugins` and confirm `compound-engineering` is listed. Also verify each required subagent and command is exposed through the current Claude Code capability surface. Invoke a `/ce-*` command only through a supported skill/command tool; never assume nested slash-command execution. When direct invocation is unavailable, execute the documented native fallback below. If a `ce-*` subagent or `/ce-*` command is unavailable, the workflow still runs with these fallbacks:

| Missing | Fallback |
|---|---|
| `compound-engineering:ce-learnings-researcher` | Dispatch a `general-purpose` agent with the generic Phase 1b prior-art fallback template in `references/discovery-agent-prompts.md`; run it alone and await it before Phase 2 |
| Any other `compound-engineering:ce-*` discovery subagent | Dispatch a `general-purpose` agent with the matching prompt template from `references/discovery-agent-prompts.md` |
| `/ce-commit`, `/ce-commit-push-pr` | Stage per scope and commit/push with native `git` following repo conventions. Only when the user requested a PR, check for `gh`; use `gh pr create` if available, otherwise finish commit/push and return the compare URL or manual PR instructions. Missing `gh` never fails the refactor. |
| `/ce-worktree` | Use `git worktree add` directly |
| `/ce-code-review` | Skip Phase 6.5, or dispatch a `general-purpose` reviewer over the unstaged diff |
| `/ce-compound`, `/ce-compound-refresh` | Write the pattern write-up directly to `docs/solutions/<slug>.md` |
| `/ce-plan`, `/ce-debug`, `/ce-simplify-code` | Note the handoff in the audit file and surface it to the user instead of invoking |

## When to Use

Trigger phrases (verbatim or paraphrased): "find SSOT opportunities", "DRY sweep", "lean refactor", "consolidate codebase", "reduce maintenance burden", "automate codebase repair", "fix everything compound", "find compounding opportunities", "hard cut", "remove legacy path", "delete compatibility layer".

Symptoms that match:
- Editor / panel / form experience feels inconsistent across consumers
- Code reviews repeatedly catch the same drift between two files
- Adding a new variant / field / breakpoint touches N files
- Comments like "keep both copies in sync" appear in code
- Helper functions exist but are unused (the SSOT was built but nobody adopted it)
- Constants are restated literally in placeholders, defaults, and labels

## When NOT to Use
- Single-file refactors — use Edit directly
- Bug fixes scoped to one function — invoke `/ce-debug`
- Net-new feature work — invoke `/ce-plan`
- Code-quality clean-up of recent changes — invoke `/ce-simplify-code`

## The Compounding Principle

A "compound" opportunity is one where a single change has an N-way blast radius. Rank findings by:

```
leverage = (sites_affected × drift_hazard_severity) / effort
```

Where:
- `sites_affected` = literal count of files / consumers / call sites that benefit per change
- `drift_hazard_severity` = 0 (cosmetic) … 3 (silent breakage / "// keep in sync" comments)
- `effort` = trivial(1) … large(4)

Tier the results:
- **Tier 1**: trivial effort, high compound — auto-approve when user said "fix everything"
- **Tier 2**: small effort, high compound — confirm with user
- **Tier 3**: medium effort, high payoff — confirm + plan
- **Tier 4**: larger structural — defer to `/ce-plan`

See `references/ranking-rubric.md` for scoring details and worked examples.

## Canonical Safety and Evidence Policy

This section is canonical. Audit files record its fields and cite it; reference templates must not restate its rules. Phase 5 tier approval still governs execution.

### Surface and state classification

Before ranking, inventory every affected reference surface: definitions, imports, call sites, dynamic dispatch/reflection/plugin registries, config, docs/examples, tests/fixtures, generated outputs, persistence/schema, migrations, serialized state, public APIs, external consumers, operational tooling, and indirect identifiers in databases, object stores, caches, queues, logs, and deployment stores. Record exact scope, query, filters, exclusions, counts, files/stores inspected, timestamp, tool/version, and raw evidence as full embedded output or durable artifact path plus content hash.

Classify each finding as `code-only` or `state-bound`, and every touched path as `canonical`, `legacy`, `temporary compatibility`, or `orchestration fallback`. Also classify whether it changes a `security-control`, applied migration, deletion, external contract/integration, or none.

- `security-control` is a terminal exclusion from compound repair. Do not consolidate, remove, bypass, or add compatibility exceptions; route to security review.
- Applied migrations are immutable. Never edit or delete one; add a new forward migration after explicit approval.
- Conservatively classify `state-bound` when any persisted key, identifier, dynamic/indirect dispatch, or unknown store may bind the old shape. Reclassify `code-only` only after complete evidence proves no such binding. Any relevant store that cannot be queried makes evidence `blocked` and prohibits a hard cut.
- State-bound repair requires pre-mutation snapshot/export with artifact path and hash; before/after transition commands, read-back and record counts; restoration command and verified restoration rehearsal/result. Never silently translate or repair invalid old state.

### Evidence gate

Label every material claim only `confirmed`, `suspected`, or `blocked`, with provenance and raw evidence. Only `confirmed` findings may enter repair. `suspected` findings remain pending; `blocked` findings record blocker and required evidence. Conflicting reports remain `suspected` or `blocked` until synthesis records each source, reconciliation decision, and evidence supporting it.

Canonicality proof must name proposed SSOT, show it owns the full intended behavior, list all consumers to migrate, and explain why no competing writer/definition remains. A name or lower duplicate count is not proof.

Before approval, capture baseline quality commands and raw results. Pre- and post-repair verification must run identical commands from equivalent environments. A failing baseline needs explicit acceptance and must not worsen. Protect behavior with the smallest focused test and demonstrate mutation sensitivity: temporarily introduce or simulate the targeted defect, capture the expected test failure, restore baseline, then capture pass. A passing test alone is not protection evidence.

Zero-reference proof requires both:
1. Negative search over recorded reference surfaces showing no legacy production references, excluding history, generated outputs, and rejection fixtures.
2. Positive control using a known surviving canonical symbol with the same search command/scope, proving search can find references.

### Hard-Cut Policy: deletion and review

Default touched product/runtime surfaces to one current-state codepath. Remove confirmed legacy bridges, fallbacks, adapters, aliases, dual reads/writes, silent coercion, and obsolete migration logic. Temporary compatibility exists only for explicitly approved external-user transition support and must record reason, canonical insufficiency, exact deletion criteria, and tracking ADR/task.

Before deletion, review diff plus inventory for lost behavior, side effects, observability, docs, tests, recovery, and external consumers. Test deletion, test skipping, reduced coverage, and assertion weakening are forbidden absent explicit approval naming exact test and reason.

Deletions, security-related findings, state-bound changes, applied/new migrations, and external contract/integration changes never auto-approve and never skip pre-commit review. Security controls remain excluded even with approval.

### Approval freshness and failure budget

Persist approval in state with approver, timestamp, exact finding IDs/boundaries, approved tier, commit/tree fingerprint, and conditions. Bind approval digest to immutable approval inputs and their artifact hashes, not the mutable audit hash. The audit path remains bound and must exist; mutable execution metadata may append without invalidating approval. Approval expires when scope, approved IDs/tier/exclusions, evidence classification, boundary diff, baseline result, reference inventory, state/external impact, or repository fingerprint changes; return to Phase 5.

Record every repair and verification outcome through `scripts/workflow.sh boundary`, which owns the durable per-boundary repair-attempt and verification-failure counters, their default limit of `2` each, and the `pending`/`completed`/`blocked` status. Every failed wave writes a manifest of boundary ID, attempt number, branch/worktree, base/diff fingerprints, allowed and changed paths, commands, raw evidence artifacts/hashes, status, blocker, and stale dependents; the coordinator binds that manifest by hash. On exhaustion the boundary becomes `blocked`, evidence is preserved, and the run requires re-plan or fresh approval. Never weaken tests or gates to fit budget.

## Workflow

### Phase 0: Pre-flight — Repository Mode and Baseline

First classify execution as `read-only discovery` or `mutating`; independently classify backing as `git-backed` or `non-git` (`code-only` isolation is a mutating non-git mode).

In `read-only discovery`, perform full discovery and return a complete inline audit. Do not write audit/state files, create issues, mutate Git, request execution approval, or start repair. Record persistence as `blocked`; stop after inline audit and never claim iterative durability.

For mutating `git-backed` targets:
1. Run `git status --short`, `git diff --stat HEAD`, and record HEAD/tree fingerprint.
2. If dirty, stop. Show affected paths and overlap risk. Iterative Git mode remains clean-only: continue from a clean dedicated worktree after the user independently commits or stashes, or explicitly choose non-Git `--code-only` isolation. Never commit or stash without user authorization.
3. Persist the clean baseline fingerprint. Code-only choice does not waive per-boundary isolation or review.

For mutating `code-only` targets, record absence of Git guarantees plus file-hash or equivalent snapshot used for freshness and rollback.

For both modes, inventory reference surfaces and run/record baseline quality commands under Canonical Safety and Evidence Policy before discovery approval.

### Phase 1: Frame the Surface

For unfamiliar codebases, **delegate to `ce-repo-research-analyst`** before dispatching the discovery wave — it returns a structured map of conventions, entry points, and module boundaries that focuses the discovery prompts.

Establish:
1. The SCOPE (whole repo? one plugin? one layer?)
2. The "already consolidated" list (read recent SSOT commits via `git log --oneline -30 --grep="refactor\|SSOT\|consolidate\|DRY"`)
3. Entry points per layer

If unclear, ask:
- "Which directory should I scan?"
- "Are there areas to skip because they were recently consolidated?"

#### Phase 1b: Prior Art (blocking, runs before Phase 2)

Dispatch `compound-engineering:ce-learnings-researcher` **alone and first**, and **wait for its result**. It surfaces prior `docs/solutions/` entries so the Phase 2 agents do not re-discover documented patterns. Summarise its output into `{{PRIOR_ART_BRIEF}}`; Phase 2 dispatch is blocked until that brief exists. If the specialist is unavailable, use the generic Phase 1b prior-art fallback template in `references/discovery-agent-prompts.md` under the same blocking rule.

### Phase 2: Parallel Discovery via CE Specialist Agents

**Parallelisation is mandatory.** Once the Phase 1b prior-art brief is in hand, spawn all remaining specialist agents in **a single assistant message** containing multiple calls to the available Claude Code subagent delegation tool (`Task` in standard Claude Code), each with the listed `subagent_type`, with the prior-art summary embedded in every prompt. The agents run concurrently. Sequential dispatch defeats the leverage promise.

Prefer compound-engineering specialist subagents over the generic `general-purpose` agent — they apply project-aware lenses by default.

| Layer | Agent (`subagent_type`) | What it surfaces |
|---|---|---|
| Pattern recognition | `compound-engineering:ce-pattern-recognition-specialist` | Duplicated patterns, anti-patterns, naming inconsistencies |
| Maintainability | `compound-engineering:ce-maintainability-reviewer` | Premature abstractions, dead code, naming-vs-intent mismatch, cross-module coupling |
| Architecture | `compound-engineering:ce-architecture-strategist` | Pattern-compliance violations, design-integrity drift, structural debt |
| Best practices | `compound-engineering:ce-best-practices-researcher` | Where the codebase deviates from current framework idioms (use when refactoring against a popular framework) |

For domain-specific layers also include:
- `compound-engineering:ce-performance-reviewer` — when query/loop-heavy code is in scope
- `compound-engineering:ce-data-migrations-reviewer` — when schema/migration files are in scope
- `compound-engineering:ce-api-contract-reviewer` — when public API surfaces are in scope
- `compound-engineering:ce-julik-frontend-races-reviewer` — when async JS / Stimulus / Turbo lifecycles are in scope
- `compound-engineering:ce-dhh-rails-reviewer` / `ce-kieran-rails-reviewer` / `ce-kieran-typescript-reviewer` / `ce-kieran-python-reviewer` / `ce-swift-ios-reviewer` — language- or framework-specific lenses

`compound-engineering:ce-learnings-researcher` is NOT part of this batch — it already ran in Phase 1b and its summary is embedded in these prompts.

**Critical agent-briefing rules** (every prompt must include):
- The Phase 1b prior-art summary, with an instruction to skip anything already documented in `docs/solutions/`
- Be EXHAUSTIVE — no "top N" caps on per-layer discovery findings, no word caps. Only the cross-cutting synthesis agent may present a ranked top 15, and the full uncapped list still lands in the audit file.
- Each finding must include: `file:line`, current scattered state (code excerpt if <8 lines), proposed SSOT location, sites_affected count, effort tier, drift_hazard_severity, and all classifications/evidence required by Canonical Safety and Evidence Policy
- Apply Canonical Safety and Evidence Policy; do not restate it
- End with a tally: total findings, total LOC duplicated, estimated LOC reduction, drift hazards count, and findings by evidence/safety classification
- End with an "already well-consolidated" list so future runs skip those
- Return findings as markdown — the orchestrator dedupes across agents

Use the templates in `references/discovery-agent-prompts.md`. For agent-sizing guidance, see the `Agent Sizing & Quota Resilience` section below.

When agents are expected to take more than a couple of minutes, use `run_in_background: true` so the orchestrator can stage other work while they run. Never poll — the harness notifies on completion.

### Phase 3: Cross-cutting Synthesis + Rank

Only after every Phase 2 layer report returns, dispatch one cross-cutting synthesis agent. It consumes full uncapped reports, applies evidence labels, deduplicates overlaps, and:
1. Groups by domain (consumers / helpers / JS / CSS / migrations)
2. Proves canonicality and classifies reference surfaces, state, security, migration, deletion, and external impact
3. Excludes security controls; leaves suspected/blocked claims out of repair candidates
4. Ranks confirmed findings by leverage and tiers them 1–4
5. Defines atomic boundaries, flags shared-file conflicts, sets each failure budget, and records score inputs plus justification for sites, hazard, effort, leverage, and tier

### Phase 4: File Findings to Disk (load-bearing)

**In mutating mode, persist before approval.** Findings live longer than the conversation context. In read-only discovery, return the complete audit inline, record persistence as blocked, and do not run this filesystem phase.

Write the consolidated, tiered findings to:

```
docs/audits/<YYYY-MM-DD>-lean-refactor-<scope>.md
```

Include:
- Date, scope, command-invocation
- Recent SSOT commits captured as "already consolidated"
- Tiered findings table with per-finding heading, file:line list, leverage score, effort, drift hazard
- Section per finding with the agent-supplied excerpt + proposed SSOT
- Deferred (Tier 4) findings clearly separated

Why mandatory:
- Survives a context-window reset mid-session
- Lets the user review async without re-running discovery
- Tier 4 deferred items remain visible for a future `/ce-plan`
- Re-runs read prior audit files first to skip already-resolved findings

Optionally also create platform issues. Both are external integrations — check availability before invoking, and skip silently if absent:
- **GitHub** (optional; requires the GitHub MCP server): use `mcp__github__create_issue` per Tier 1+2 finding (title = finding heading; body = the audit-file section). Attach a `lean-refactor` label.
- **Plane.so** (optional; requires the `plane` skill to be installed): use the `plane` skill to create work items in the project's "Refactor" cycle.

If the repo has a project tracker, prefer it — issues are searchable and assignable. If not, the markdown file is the SSOT.

### Phase 5: User Approval Gate

Surface the audit-file path to the user. Ask:
- "Execute Tier 1 only? Tiers 1+2? All?"
- "Any specific findings to skip?"
- "Should I batch related findings into one commit per consolidation?"

Auto-approve Tier 1 only when the user said "fix everything automatically" or similar, repository pre-flight is satisfied, evidence is confirmed, baseline passes, and finding is not deletion, security-related, state-bound, migration, or external. Persist approval freshness fields before repair.

For Tier 4 escalations, hand off to `/ce-plan` and stop the loop.

### Phase 6: Isolated Repair via Atomic Boundaries

Group findings by **atomic commit boundary**. For every approved boundary in a Git-backed target, create a dedicated worktree and named branch from approved base fingerprint via `/ce-worktree` (or `git worktree add -b <session>/<boundary> <path> <base>`); detached HEAD is forbidden. Persist exact allowed-path manifest, dependency order, and boundary-specific commit authorization tied to approved finding IDs/diff fingerprint. Require clean index before and after staging; stage only allowlisted paths and reject unexpected staged/untracked changes. For code-only targets, create an equivalent isolated copy/snapshot per boundary and record limitation. Never repair in discovery/baseline workspace.

Only integration workspace owns audit file, which is excluded from boundary manifests/commits and updated in a dedicated metadata change. Repair agents never commit. After reviewer approval, orchestrator authorizes one boundary commit, then cherry-picks verified commits into integration branch in dependency order. On conflict, abort cherry-pick, preserve evidence, and return boundary plus stale dependents to approval; never resolve under stale approval.

Each repair agent:
1. Reads approved audit boundary and verifies fingerprint/freshness
2. Reads current affected files and reference inventory
3. Adds/identifies test protection before destructive edits
4. Edits only confirmed scope under canonical policy; never edits applied migrations or security controls
5. Runs identical baseline commands, deletion review, and positive-control zero-reference proof
6. Stops at failure budget; returns evidence and diff summary (NEVER commits — orchestrator owns Git)

Use the prompt template in `references/repair-agent-prompt.md`. Pass the audit-file path so each agent has full context for its boundary.

#### Agent Sizing & Quota Resilience

Big single agents are fragile — a quota error mid-run leaves partial work scattered across files. **Split repair agents when**:

- The boundary touches **>10 files** — split by sub-scope (e.g. "rewrite the helpers" + "adopt the helpers in widgets")
- The boundary touches **>500 LOC of edits** — split by file group
- The boundary requires **>5 distinct sub-tasks** — split per sub-task with explicit `blockedBy` ordering

When splitting, declare `blockedBy` between agents that must run sequentially (e.g. helpers must land before adoption).

#### Conflict Avoidance

If two boundaries touch the same file, run them sequentially. The second agent must read the file AFTER the first lands. Pre-flag conflicts during Phase 3 grouping; sequence them in the dispatch.

### Phase 6.5: Pre-commit Code Review

Invoke `/ce-code-review` on every Tier 2/3 boundary and every deletion, security-related, state-bound, migration, or external boundary regardless of tier. Security-control findings cannot reach this phase. Tier 1 code-only internal non-deletions may skip review only when approval permits.

Review canonicality proof, behavior/test protection, deletion checklist, migration immutability, state transition, external impact, and evidence. Persist structured reviewer record: reviewer identity, ISO-8601 timestamp, reviewed diff fingerprint, checklist item results, findings, and verdict. Minor findings consume repair attempts; structural findings invalidate approval and return to Phase 5.

### Phase 7: Verify + Atomic Commits via /ce-commit

For each repair scope:
1. Recheck approval freshness against boundary fingerprint and evidence.
2. Run exactly the recorded baseline quality commands in equivalent environment; compare results and consume failure budget on failure.
3. Capture negative and positive-control zero-reference evidence plus deletion review.
4. Confirm no test was deleted/skipped and no assertion weakened without recorded explicit approval.
5. Stage only that worktree boundary and invoke `/ce-commit`; never cross-stage scopes.
6. Confirm hash/clean worktree, integrate boundary, then rebase/recreate later worktrees if fingerprint changed and return affected approvals to Phase 5.

Surface a final tally:
- Findings addressed
- LOC reduction
- Drift hazards eliminated
- Legacy product/runtime paths removed, with zero-reference proof
- Temporary compatibility exceptions remaining, with ADR/task and deletion criteria
- Commits created (hashes)

If the user wants the work shipped, chain to **`/ce-commit-push-pr`** at the end. Its native fallback always completes commit/push first. Check for `gh` only when a PR was requested: use `gh pr create` when available; otherwise return the repository compare URL (or precise manual PR steps) with the adaptive description. Missing `gh` does not fail or roll back the refactor.

### Phase 8: Capture Learnings via /ce-compound

After commits land, invoke `/ce-compound` through a supported command/skill capability; otherwise write the pattern directly to `docs/solutions/<slug>.md` to document the SSOT patterns discovered (e.g. "PHP→CSS variant generator", "auto-flatten registry pattern", "factory eliminates filename-vs-version drift"). This compounds: future runs of lean-refactor on the same codebase find the patterns documented and avoid re-proposing them.

Optionally chain `/ce-compound-refresh` to audit existing `docs/solutions/` for entries this refactor superseded.

### Phase 9: Update the Audit File

Mark resolved findings in the audit file. For findings deferred to a later run, leave them in place with a `Status: deferred` annotation. Append machine lifecycle fields only through `scripts/workflow.sh finalize`; duplicate keys are append-only and the last exact `compound_<key>:` line wins. The audit file becomes the canonical record for that scope.

In Git mode, commit the audit alone as a dedicated metadata boundary through `/ce-commit` when that command is callable, or native Git fallback after the same clean-index and allowlist checks. Do not leave an unexplained dirty audit. The metadata commit is separate from repair boundaries and appears in the final tally.

## Delegation Map — Compound-Engineering Resources Per Phase

| Phase | Delegated agent / skill | Purpose |
|---|---|---|
| 0 — pre-flight | explicit user choice; `/ce-commit` only if chosen | Stop on dirty tree; record mode, consent, fingerprint, and baseline |
| 1 — frame scope | `compound-engineering:ce-repo-research-analyst` | Map conventions for unfamiliar codebases |
| 1b — prior art | `compound-engineering:ce-learnings-researcher` | Surface `docs/solutions/` entries to skip |
| 2 — discovery | `compound-engineering:ce-pattern-recognition-specialist`, `ce-maintainability-reviewer`, `ce-architecture-strategist`, plus domain-specific reviewers | Specialist layer scans (parallel) |
| 4 — file findings | (write to `docs/audits/`) plus optional `mcp__github__create_issue` or `plane` skill | Persist findings outside conversation context |
| 5 — approval | (user prompt) | Tier selection |
| 6 — repair | `/ce-worktree` per boundary, then parallel non-conflicting subagent delegation calls | Isolated atomic consolidations |
| 6.5 — pre-commit review | `/ce-code-review` | Tiered persona review of repair diffs |
| 7 — commit | `/ce-commit` per scope | Repo-convention messages |
| 7b — ship | `/ce-commit-push-pr` (optional) | Push + PR with adaptive description |
| 8 — capture | `/ce-compound` | Document SSOT patterns for future runs |
| 8b — refresh | `/ce-compound-refresh` (optional) | Audit `docs/solutions/` for superseded entries |
| 9 — update audit | (in-orchestrator) | Mark resolved / deferred in `docs/audits/` |

For Tier 4 findings escalated out of this run, hand off to `/ce-plan`.

## Iterative Loop

From repo root, initialize through `scripts/workflow.sh init [SCOPE] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]`; capture the printed session and state paths. Use the same coordinator for approval, boundary results, wave finalization, zero-finding discovery conclusion, status, and cancellation. Iteration writes `.claude/lean-refactor.<session-id>.local.md` plus its boundary ledger and defaults to `max-iterations=10`, `tier-floor=2`. Continuation is active only when the host adapter registers `scripts/stop-hook.sh` at its stop lifecycle boundary and supplies the documented JSON payload. Setup does not register the adapter. Without it, the run is single-turn and must not claim automatic continuation.

Two whole-line markers stop the loop (nothing else does):

- `<lean-refactor-complete>` — re-discovery returned 0 findings at or below the tier floor
- `<lean-refactor-stuck>` — findings identical to the previous iteration; halt and surface

Cancel from repo root through `scripts/workflow.sh cancel --root "$(pwd)" <SESSION_ID>` — removes valid session state and preserves source changes. A host command wrapper is valid only if separately registered to run that exact coordinator contract.

Full state-file schema, hook decision logic, re-entrance handling, and rationalisations-to-reject live in `references/iterative-loop.md`.

## Parallelisation Rules (load-bearing)

- **Discovery**: ALL Phase 2 discovery agents in ONE assistant message. Multiple subagent delegation calls in the same response. This excludes the blocking Phase 1b `ce-learnings-researcher`, which runs alone and is awaited first. Sequential Phase 2 dispatch defeats the workflow.
- **Repair**: ALL non-conflicting boundaries in ONE assistant message. Conflicts (two scopes touching the same file) run sequentially with a `blockedBy` declaration.
- **Verification**: lint / test runs per file are CPU-bound — also run in parallel via `Bash` tool with multiple invocations in one message.
- **Background mode**: when discovery agents are expected to take >2 minutes, use `run_in_background: true`. Never poll — the harness notifies on completion.
- **Sizing**: split repair agents that would touch >10 files or >500 LOC; declare `blockedBy` for sequencing.

If the orchestrator finds itself dispatching agents one-at-a-time across multiple turns, STOP and re-dispatch as a parallel batch.

## Anti-Patterns

Do NOT:
- Cap discovery at "top 10" — exhaustiveness is the value
- Use `general-purpose` agents when a `ce-*` specialist exists for the layer
- Run repair before Phase 5 approval or policy-qualified Tier 1 auto-approval
- Mix unrelated findings in one commit — atomicity > speed
- Skip the audit-file write in mutating mode — findings must persist outside conversation context; read-only discovery returns the complete audit inline
- Skip the verification step
- Forget the "already consolidated" list — it prevents undoing past SSOT work
- Ignore drift hazards in favour of raw LOC counts — a 3-LOC fix that eliminates a `// keep in sync` comment beats a 30-LOC reduction with no drift risk
- Dispatch one giant repair agent for >10 files / >500 LOC — split for quota resilience
- Preserve or introduce compatibility outside the canonical policy exception gate
- Touch security controls, applied migrations, or state/external surfaces without required exclusion or explicit approval
- Delete tests, skip tests, weaken assertions, or change quality commands to pass
- Start repair on suspected/blocked evidence or stale approval

DO:
- In mutating mode, file findings to `docs/audits/<date>-lean-refactor-<scope>.md` before user approval; in read-only discovery, return them inline without writing
- Group by atomic commit boundary
- Run layer discovery in parallel, then cross-cutting synthesis
- Run approved repairs in per-boundary worktrees, parallel only when non-conflicting
- Prefer `ce-*` specialist subagents per layer (pattern-recognition, maintainability, architecture, plus language reviewers)
- Tag drift hazards explicitly — sync-comment patterns are gold
- Capture learnings via `/ce-compound` after the refactor lands
- Delegate every **mutating** git operation (commits, pushes, PRs) to `/ce-commit` or `/ce-commit-push-pr`; read-only inspection (`git status`, `git diff`, `git log`) runs inline

## Resources

### Reference Files

- **`references/discovery-agent-prompts.md`** — Per-layer prompt templates (consumers, infrastructure, frontend, cross-cutting). Each template specifies the recommended `subagent_type`.
- **`references/ranking-rubric.md`** — Scoring formula + tier definitions + worked examples
- **`references/repair-patterns.md`** — Templated repair recipes for the 9 most common SSOT patterns
- **`references/repair-agent-prompt.md`** — Prompt template for parallel repair agents
- **`references/iterative-loop.md`** — State-file schema, hook decision logic, marker semantics, rationalisations
- **`references/methodology.md`** — Detailed walkthrough of the full workflow with a real-world example
- **`references/audit-file-template.md`** — Markdown template for `docs/audits/<date>-lean-refactor-<scope>.md`

### Scripts

- **`scripts/workflow.sh`** — Public coordinator entry for lifecycle initialization, approval, boundary outcomes, finalization, status, and cancellation
- **`scripts/setup-loop.sh`**, **`record-approval.sh`**, **`record-boundary-result.sh`**, **`record-wave.sh`** — Coordinator implementation adapters; invoke through `workflow.sh`
- **`scripts/stop-hook.sh`** — Stop-hook entry point; decides whether to re-enter the loop
- **`scripts/cancel-loop.sh`** — Internal cancellation adapter used by `workflow.sh`
- **`scripts/lib.sh`** — Shared state-file field parsing, sourced by the other scripts (not invoked directly)
- **`scripts/stage-findings.sh`** — Assemble the raw agent reports into one concatenated file for the orchestrator to dedupe and rank
- **`scripts/file-findings.sh`** — Create a new audit scaffold in `docs/audits/` from the canonical template

Iterative continuation needs `stop-hook.sh` registered at the host stop boundary. Cancellation runs through `workflow.sh cancel` and preserves file changes.
