# Ranking Rubric

Scoring detail for confirmed findings under canonical workflow in `../SKILL.md`. Rubric ranks work; it never grants approval or overrides repair stop conditions.

## Eligibility

Score only `evidence_state: confirmed` findings with complete reference surfaces and proven semantic equivalence. Keep `suspected` and `blocked` candidates in audit evidence appendix, unranked.

## Formula

```
leverage = (sites_affected × drift_hazard_severity) / effort
```

Then bucket into tiers.

## Component Definitions

### `sites_affected`

Count of independent call sites / files / fields / widgets that benefit from one consolidation. Be literal — count actual locations.

| Sites | Compound rating |
|---|---|
| 1 | Not compound — skip unless drift_hazard ≥ 2 |
| 2–3 | Mild — only worth it if effort is trivial |
| 4–8 | Compound |
| 9+ | High compound — prioritize |

### `drift_hazard_severity`

How likely is the current scattered state to cause a bug?

| Score | Meaning | Examples |
|---|---|---|
| 0 | Cosmetic | Variable name inconsistency, doc-comment phrasing |
| 1 | Latent | Two files happen to agree today; nothing forces it |
| 2 | Likely | Repeated literals with no test coverage; sync-comment patterns |
| 3 | Active drift | Already-divergent values, broken paths, `// keep both copies in sync` comments, dead unreachable code, orphan files |

### `effort`

Realistic implementation cost (not "ideal world"):

| Score | Bucket | Time | Examples |
|---|---|---|---|
| 1 | Trivial | < 15 min | Promote literal to const, delete dead code, update sed pattern |
| 2 | Small | 15–60 min | Extract trait, add helper + repoint < 10 callers |
| 3 | Medium | 1–4 hours | Refactor base class, introduce schema-driven generation |
| 4 | Large | > 4 hours | Cross-cutting type-system change, breaking API |

## Tiers

After scoring, bucket findings:

Buckets are mutually exclusive — `effort` alone decides which tier a finding can land in, and the leverage threshold decides whether it qualifies at all:

- **Tier 1** — `effort = 1` AND (`leverage ≥ 4` OR `drift_hazard = 3`)
- **Tier 2** — `effort = 2` AND (`leverage ≥ 6` OR `drift_hazard = 3`)
- **Tier 3** — `effort = 3` AND (`leverage ≥ 12` OR `drift_hazard = 3`)
- **Tier 4** — `effort = 4` (defer to `/ce-plan`)

A finding below its tier's leverage threshold with `drift_hazard < 3` is not tiered — it goes to the audit file's long tail.

`drift_hazard = 3` never moves a finding into a lower-effort tier. Tier 1 is the auto-approvable bucket, so promoting nontrivial work into it would auto-approve work the user never sized. An active-drift finding stays in its effort-appropriate tier and is flagged prominently in the approval summary (lead with it, label it `ACTIVE DRIFT`) so the user can pull it forward deliberately.

## Worked Examples

### Example 1: `'+{n} tags'` literal duplicated with sync comment

- `sites_affected = 2` (placeholder + renderer fallback)
- `drift_hazard_severity = 3` (active sync-comment, textbook drift hazard)
- `effort = 1` (promote to class const)
- `leverage = (2 × 3) / 1 = 6`
- **Tier 1** — high drift, trivial fix

### Example 2: Hoist `*_pair()` static methods

- `sites_affected = 9` (3 widgets × 3 helpers, verbatim duplicates)
- `drift_hazard_severity = 2` (one already drifted between card and wrapper)
- `effort = 1` (move to helpers.php, repoint callers)
- `leverage = (9 × 2) / 1 = 18`
- **Tier 1** — highest leverage in this class

### Example 3: Schema-driven Twig data-shape contracts

- `sites_affected = 1` widget with full PHP↔Twig double-walker
- `drift_hazard_severity = 2` (silent breakage if shape evolves)
- `effort = 4` (requires PHPStan investment + typed shape contracts)
- `leverage = (1 × 2) / 4 = 0.5`
- **Tier 4** — defer to `/ce-plan`

### Example 4: `EF_Voxel_Templates` constants

- `sites_affected = 11` template strings across 8 files
- `drift_hazard_severity = 2` (Voxel renames have happened — migration 410)
- `effort = 1` (1 new file, mechanical replace)
- `leverage = (11 × 2) / 1 = 22`
- **Tier 1** — minutes of effort, high future-proofing

### Example 5: Adopt unused `ef_vx_*_pair()` helpers

- `sites_affected = 30+` scalar fields across 9 widgets
- `drift_hazard_severity = 1` (helper exists, just not used — boilerplate not bug)
- `effort = 2` (mechanical refactor across many files)
- `leverage = (30 × 1) / 2 = 15`
- **Tier 2** — high LOC reduction but no active drift; needs user batch confirmation

## Drift Hazards Always Surface

`drift_hazard_severity = 3` qualifies a finding for its tier regardless of `leverage`, but never moves it into a lower-effort tier — a medium-effort drift fix stays Tier 3. Instead, flag it `ACTIVE DRIFT` and lead the approval summary with it, so the user pulls it forward deliberately rather than auto-approving unsized work. Active drift is bug debt accruing interest. Examples:

- `// keep both copies in sync` comments
- Two CSS values for the same breakpoint (`767px` vs `767.98px`)
- Helper file orphaned but consumed-via-fallback
- Dead code in a base class subclasses still call

## Output Format

Master list groups by tier, then by domain within tier. Each finding:

```
### [Tier 1] Title (imperative)
- **Files**: path:line, path:line, ...
- **Current**: <what's scattered, with code excerpt if <8 lines>
- **Proposed SSOT**: <where the consolidation lives>
- **Sites affected**: N — <literal-count justification>
- **Drift hazard**: 0–3 — <evidence justification>
- **Effort**: 1–4 — <estimate justification>
- **Leverage/tier**: <calculation> — <threshold justification>
- **Evidence state**: confirmed
- **Search provenance**: <query/root/filters/count>
- **Semantic equivalence**: <why behavior and contracts match>
```

No cap on findings. Every finding, at every tier, lands in the audit file — the audit file is the exhaustive record. Only the user-facing summary may abbreviate, showing the top N per tier by leverage with a count of the remainder ("Tier 2: showing 10 of 34").

## Anti-Pattern: LOC-Only Ranking

LOC reduction is a side-effect, not the goal. A 5-LOC change that eliminates a sync-comment beats a 100-LOC reduction with no drift risk. Always compute leverage with `drift_hazard_severity`, not raw LOC.
