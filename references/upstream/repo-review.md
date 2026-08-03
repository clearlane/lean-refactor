# Absorbed Source: repo-review

One file per absorbed source. This one records what `repo-review` contributed,
what was deliberately left behind, and the evidence binding the merge, so a
later reader can tell absorbed capability from original design without reading
the diff.

## Baseline

| Field | Value |
|---|---|
| Location | Project-local skill, previously at `skills/repo-review/` |
| Upstream | None. Never published, no version control, nothing to refresh from. |
| Baseline digest | Snapshot tree SHA-256 `759e6cecd196241478a9425f3b909c14d89b07fa7527d1c802176370aea9a73d` |
| Absorbed on | 2026-08-03 |
| Plan hash | `73fd477b4137d2dff585f8442aa47bf4cc3f49723f275ce0ccbdca618b8521ad` |

## Why It Was Absorbed

`repo-review` was built as a standalone read-only repository reviewer. It was
not a sibling skill: it was this skill's own read-only mode, declared in the
contract as "Execution mode: read-only discovery or mutating" and routed in
Execution Routing, but never implemented. State validation only ever knew
`mode` as `git|code-only`, which is isolation backing rather than depth.

Absorbing it as the `review` depth implemented the branch the contract had
already promised, instead of shipping two skills that discover the same way.

## Absorbed

- Read-only terminal that publishes findings without manufacturing an approval, now `scripts/review-report.sh` and the `reported` phase.
- `severity` as an impact axis independent of effort, now scored alongside `leverage` on every confirmed finding.
- A published severity floor, defaulting to `P2`, with everything below it retained in the audit long tail.
- `structure`, `tests`, `docs`, and `security` review dimensions, merged into the one canonical lens table.
- Blocked-lens visibility and the mandatory coverage-gaps section, so a narrower run is visible as one.
- Cross-lens merging that keeps the worst severity and records every corroborating lens, plus the defect-titling rule that makes merging possible.

## Reworked or Excluded

- Excluded its Python coordinator, state module, and evidence gate. This skill already owns phase ordering, locking, resume, and evidence validation in Bash with test coverage; a second coordinator in a second language is the duplication this skill exists to remove.
- Excluded its layered settings resolver. This skill takes explicit validated flags, and a settings layer would add a second input surface for the same values.
- Excluded its slash-command adapter. The Coordinator Entry section already serves that role.
- Moved its check coverage — phase ordering, resume from persisted state alone, and terminal idempotence — into `tests/depth.bats` rather than dropping it.
- Deleted the project-local source tree after the run. Run artifacts retain the inventory, per-source analysis, bound plan, merge evidence, and validation record.

## Canonical Destinations

- `SKILL.md`
- `scripts/review-report.sh`
- `scripts/state.sh`
- `references/ranking.md`
- `references/worker-discovery.md`
- `references/audit.md`
- `tests/depth.bats`
