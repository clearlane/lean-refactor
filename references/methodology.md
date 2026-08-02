# Methodology — Worked Walkthrough

Detailed execution guide. Safety and evidence invariants live in `../SKILL.md`; executable transitions live in `../scripts/workflow.sh` and `workflow.md`.

## 1. Frame and establish evidence

Resolve execution mode separately from backing. Read-only discovery returns complete inline audit, records persistence blocked, and stops before approval/repair. Mutating Git mode requires clean tree before state creation; mutating code-only mode records unavailable Git guarantees. Load recent audits and solutions as prior art where readable.

Example scope map:

- consumers: components and handlers
- infrastructure: registries and helpers
- contracts: templates, schemas, assets

Generate a compact deterministic frame before layer dispatch when useful:

```text
scripts/repo-frame.sh SCOPE --output /absolute/path/repo-frame.json
```

Add `--run-cpd` when clone-candidate generation is appropriate; tune `--cpd-min-lines` and `--cpd-min-tokens` for the scope. The normalized artifact records whether CPD ran and the exact effective command shape.

The adapter always records available tool versions and a compact file/language inventory. It reuses a ready CodeGraph index but marks an index with pending changes or a recommended rebuild as `stale`; it does not create or update `.codegraph/` unless `--init-codegraph` is explicitly authorized. For supported languages, use CodeGraph `query`, `callers`, `callees`, `impact`, and `affected` JSON output to reduce file crawling. CodeGraph is not complete evidence for unsupported languages, configuration, serialized identifiers, external state, or dynamic surfaces outside its graph.

Use `scc` output for language/LOC/generated-code framing, CPD output for syntactic clone candidates, and `ast-grep` for structural searches when available. Accelerator results remain candidate evidence; semantic equivalence, canonicality, persisted-state coverage, and hard-cut safety still require the canonical evidence procedure.

## 2. Discover in correct order

1. Run blocking prior-art pass.
2. Generate or load the deterministic repository frame and pass its artifact path to every layer scan.
3. Dispatch independent layer scans in one parallel batch using `worker-discovery.md`.
4. Wait for every report.
5. Run cross-cutting synthesis later over complete reports.

Record the prior-art, complete aggregate layer-report, synthesis, and persisted audit artifacts through `workflow.sh discovery`. The coordinator rejects missing or out-of-order checkpoints. Use host-native specialists matching the capability roles in `worker-discovery.md`; when unavailable, use a bounded general-purpose worker with the same contract. Use the host's bounded parallel primitive for independent layer scans and completion notifications for longer work.

Layer reports preserve full provenance/raw artifacts, complete dynamic/indirect and persisted-store surfaces, canonical `confirmed|suspected|blocked` evidence, and semantic-equivalence analysis. Synthesis records conflict reconciliation and score justifications; it never races scans it consumes.

## 3. Rank and persist

Deduplicate confirmed findings, flag overlapping files, score using `ranking.md`, then create audit from `audit.md`. Persist exhaustive findings before showing abbreviated summary.

Example:

| Finding | Sites | Hazard | Effort | Leverage | Tier |
|---|---:|---:|---:|---:|---:|
| Thread registry field through missing consumer | 6 | 3 | 1 | 18 | 1 |
| Adopt existing shared helper | 24 | 1 | 2 | 12 | 2 |
| Replace duplicated state schema | 5 | 2 | 3 | 3.33 | long tail |
| Redesign migration family | 8 | 3 | 4 | 6 | 4 |

Record approval through `scripts/workflow.sh approve` before repair. Persist approver identity, conditions, selection, exclusions, timestamp, evidence artifacts, repository fingerprint, and digest in state/audit. The coordinator owns digest construction and initializes one ledger entry per approved finding ID.

Tier 1 may auto-approve only when the user explicitly requested automatic repair, evidence and baseline are confirmed, and the boundary is not a deletion, security surface, state-bound change, migration, or external contract. Tier 2 and 3 require explicit approval. Tier 4 exits to a planning handoff.

## 4. Repair isolated boundaries

Group non-conflicting findings by atomic boundary. In Git mode, create named branch/worktree per boundary from approved base, enforce allowed-path/index protocol, then integrate authorized commits by dependency-ordered cherry-pick; abort conflicts and reapprove stale dependents. Integration workspace alone updates audit metadata. In code-only mode, use isolated snapshot and never imply Git guarantees.

Split oversized boundaries by a real dependency graph when they exceed roughly ten files, five distinct subtasks, or 500 changed lines. Start non-conflicting boundaries together through bounded parallel delegation; shared-file boundaries run sequentially after the predecessor lands. Workers never commit. The coordinator records structured `completed`, `retryable`, `failed`, or `blocked` outcomes and evidence manifests before retry or continuation.

Each repair receives `worker-repair.md` with:

- coordinator state path and immutable approval digest
- confirmed finding IDs and fresh approval digest
- baseline commit or `code-only`
- dedicated worktree path where applicable
- baseline test/lint evidence
- exact files and expected removals

Focused tests require mutation/simulation failure then restored pass before edit. State-bound work captures snapshot/export, transition/read-back/counts, and verified restoration evidence. Security controls stay excluded; migration immutability and unknown/unqueryable state stop repair.

Use a preferred review capability for Tier 2/3 and every deletion, state-bound change, migration, or external contract. If unavailable, use a bounded general-purpose reviewer with the same checklist. Structural review findings invalidate approval; minor findings consume the repair attempt budget.

## 5. Verify and close

Compare baseline/post commands and results. Require protected tests, project checks, and canonical zero-reference evidence. Record repair and verification outcomes through `scripts/workflow.sh boundary`; finalize only when every approved boundary has completed both stages. Update audit status, measured delta, failures, deferred items, and commit IDs where Git mode applies. Re-discovery provides convergence evidence; memory does not.

The orchestrator alone authorizes and creates atomic commits after review and verification. Prefer the repository's installed commit/PR capability; otherwise use native Git with clean-index and exact allowlist checks. Push or open a PR only when requested. Commit audit metadata separately from repair boundaries, then write reusable patterns to `docs/solutions/` when no dedicated learning-capture capability exists.

## Example final summary

```markdown
Findings addressed: 6
LOC delta: -184
Drift hazards removed: 3
Protected tests: baseline PASS, post PASS
Legacy references: 12 before, 0 after
Deferred: migration redesign; state ownership blocked
Audit: docs/audits/2026-08-01-lean-refactor-api.md
```

Framework-specific commands such as `npm test`, `cargo test`, `php -l`, or browser checks are examples. Select repository-native quality stack from evidence.
