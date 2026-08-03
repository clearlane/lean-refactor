---
name: lean-refactor
description: Reviews a repository and fixes what it finds, through one evidence-gated workflow with two depths — a read-only ranked report, or approved consolidation of compounding SSOT/DRY findings. Triggers on repo review, code audit, architecture or health review, lean refactor, DRY sweep, hard cut, remove legacy paths, or consolidate codebase. Not for single-file review or refactor, diff-only review, scoped bug fixes, or net-new features.
---

# Lean SSOT Refactor

Use this skill for repository-wide work that must argue from evidence: reviewing a whole repository and publishing a ranked report, or consolidating drift where one canonical change removes it across multiple consumers, files, modules, schemas, tests, or operational surfaces. Do not use it for one-file cleanup, diff-only review, one-function bugs, new features, or recent-change simplification.

Review and refactor are one workflow at two depths, not two skills. Both frame the repository, consult prior art, run the same lenses in parallel, and synthesize one audit. They diverge once, after the audit is ready: a review publishes it and stops; a refactor takes it to approval and repair.

## Contract

Inputs:

- A trusted repository or explicit scoped directory.
- Depth: `review` (read-only, terminates at a published report) or `refactor` (continues into approved mutation). Defaults to `refactor`.
- Backing mode: Git or explicitly selected code-only isolation.
- Repository-native baseline checks and complete evidence surfaces.

Outputs:

- Exhaustive audit with confirmed, suspected, and blocked findings.
- For review: one ranked report at or above the severity floor, plus an explicit coverage-gaps section naming blocked lenses and withheld claims.
- Ranked atomic boundaries with canonicality proof and reproducible evidence.
- For approved mutations: isolated repairs, verification artifacts, commits when authorized, and convergence evidence.

Depth and backing are orthogonal. Depth decides where the run terminates; backing decides what isolation guarantees mutation has. Either depth is legal under either backing mode.

`jq` and Bash are required for resumable runs. CodeGraph, `scc`, a CPD implementation, and `ast-grep` are optional discovery accelerators; absence or unsupported languages must fall back deterministically. Use host-native bounded delegation, review, planning, and learning-capture capabilities when available; [methodology.md](references/methodology.md) defines capability-based fallbacks without requiring a particular runtime or plugin.

## Coordinator Entry

For mutating or resumable work, initialize:

```text
scripts/workflow.sh init [SCOPE] [--depth review|refactor] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

Keep the returned state path. Use only these coordinator transitions:

- `discovery` — bind prior-art, layer-report, synthesis, and audit artifacts in order.
- `report` — publish the audit and terminate a `--depth review` run. Refuses a refactor run.
- `approve` — bind approver, conditions, exact findings, evidence, and repository fingerprint.
- `verify-approval` — enforce freshness immediately before mutation.
- `boundary` — record one approved boundary's repair or verification outcome.
- `finalize` — close a wave only after every approved boundary completes.
- `conclude-discovery` — close a zero-repair discovery iteration.
- `advance` — evaluate markers and resume or terminate; normally called by the host event adapter.
- `status` and `cancel` — inspect or terminate durable state.

The coordinator owns ordering, transitions, retries, counters, approvals, and resume state. Workers return bounded artifacts and never edit workflow state. Read [workflow.md](references/workflow.md) for exact command contracts and state semantics.

## Safety and Evidence Invariants

Before ranking, inventory definitions, imports, call sites, dynamic dispatch, registries, configuration, docs, tests, generated outputs, persistence, migrations, serialized state, public APIs, external consumers, operational tooling, and indirect identifiers in external stores. Record exact query, root, filters, exclusions, counts, locations, timestamp, tool/version, and full raw evidence or artifact path plus hash.

Classify every material claim as `confirmed`, `suspected`, or `blocked`. Only confirmed findings may enter repair or a published report; `suspected` and `blocked` claims are retained and listed under coverage gaps rather than deleted, because they record where the next run should look. Canonicality proof must name the proposed owner, show that it owns the full intended behavior, list every consumer, and prove no competing writer remains.

Score every confirmed finding on both axes defined in [ranking.md](references/ranking.md): `severity` for impact and `leverage` for compound value. They answer different questions, and dropping either loses real defects — a single-site defect that breaks a stated guarantee is `P0` and never compound enough to be tiered.

Classify every finding as `code-only` or `state-bound`; every touched path as `canonical`, `legacy`, `temporary compatibility`, or `orchestration fallback`; and special impact as `security-control`, applied/new migration, deletion, external contract/integration, or none.

- Security controls are terminal exclusions from compound repair.
- Never edit or delete an applied migration; use an explicitly approved forward migration.
- Unknown or unqueryable persisted state makes a hard cut blocked.
- State-bound repair requires a hashed snapshot/export, transition and read-back counts, restoration command, and verified restoration evidence.
- Baseline and post-repair checks must be identical and run in equivalent environments. An accepted failing baseline must not worsen.
- Focused protection requires mutation/simulation sensitivity: expected failure, restored baseline pass, then repaired pass.
- Zero-reference proof requires a negative legacy search and a positive control using the same search scope.
- Never delete, skip, weaken, or make tests less specific without explicit approval naming the exact test and reason.

Default touched runtime surfaces to one current path. Remove confirmed aliases, fallbacks, bridges, dual reads/writes, silent coercions, and obsolete compatibility. Temporary compatibility requires explicit external-transition approval, reason, canonical insufficiency, exact deletion criteria, and a tracking ADR/task.

Deletions, state-bound changes, migrations, and external contracts never auto-approve and never skip review. Approval must bind approver, timestamp, exact finding IDs/boundaries, tier, exclusions, conditions, repository fingerprint, and evidence artifact hashes. Any approval-bound change returns the workflow to approval.

Every failed repair or verification records a hashed manifest. The coordinator owns separate per-boundary repair-attempt and verification-failure counters, default limit `2`; exhaustion is terminal `blocked`. Never weaken a gate to fit the failure budget.

## Execution Routing

Steps 1 through 6 are the shared spine and run identically at both depths. Step 7 is the only branch point.

1. Choose depth at initialization with `--depth`. For mutating Git runs, require a clean dedicated worktree before initialization. Never stash or commit user work without authorization. Use `--code-only` only as an explicit non-Git choice.
2. Run prior art first; record it with `workflow.sh discovery --stage prior-art`.
3. Create an optional deterministic repository frame with `scripts/repo-frame.sh SCOPE --output ARTIFACT`. Reuse an existing CodeGraph index when ready; initialize one only with explicit authorization via `--init-codegraph`. Include the frame in every layer brief.
4. Run independent discovery lenses through bounded parallel delegation; persist their complete aggregate with `--stage layers`. Record a lens that could not run as blocked, with its reason.
5. Run synthesis only after all layer reports; persist it with `--stage synthesis`.
6. Persist the exhaustive audit and record it with `--stage audit`.
7. Branch on depth. A `review` run publishes the audit with `workflow.sh report` and terminates; it can never acquire approval. A `refactor` run continues to step 8.
8. Obtain and persist exact approval before mutation.
9. Repair one atomic boundary per worker in an isolated named worktree or code-only snapshot. Parallelize only non-conflicting boundaries.
10. Record repair and verification outcomes through `workflow.sh boundary`; the coordinator rejects out-of-order, unapproved, blocked, or incomplete work.
11. Finalize the wave, integrate verified commits in dependency order, update audit metadata separately, capture reusable learnings, and rediscover.

Read [methodology.md](references/methodology.md) for the detailed execution procedure, capability fallbacks, concurrency, Git ownership, and handoff rules. Use [worker-discovery.md](references/worker-discovery.md) for discovery workers, [ranking.md](references/ranking.md) for scoring, [audit.md](references/audit.md) for persistence, and [worker-repair.md](references/worker-repair.md) for one approved repair boundary. [repair.md](references/repair.md) contains non-normative recipes.

## Completion

Emit `<lean-refactor-complete>` only after `workflow.sh conclude-discovery` records zero repair-ready findings at or below the tier floor. Emit `<lean-refactor-stuck>` only when the current and previous normalized finding signatures are identical and audit-backed. The host event adapter delegates marker decisions to `workflow.sh advance`; marker text alone has no authority.

Before handoff, run the target repository's native checks. When this skill's own files changed, run `scripts/check.sh`; it owns the complete check list, so no caller restates the individual commands.

Name every resource you add or rename with one lowercase word, or a family-first lowercase hyphenated stem when one word is ambiguous. Put the stable family first (`loop-setup.sh`, not `setup-loop.sh`) so siblings sort together, and avoid generic segments such as `helper`, `utils`, or `new`. `scripts/names.sh` enforces this and preserves names fixed by an external contract.
