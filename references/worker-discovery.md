# Discovery Agent Prompts

Templates supplement canonical workflow in `../SKILL.md`; they do not redefine approval, hard-cut, scheduling, or persistence policy.

## Dispatch contract

Run prior-art discovery first. After it returns, dispatch all layer scans in one parallel batch. Run cross-cutting synthesis **later**, after every layer report exists; give it the complete layer reports. Never run synthesis in parallel with scans it must synthesize.

This dispatch is identical at both depths. A review run and a refactor run discover the same way and diverge only after synthesis, so a lens never needs to know which depth invoked it.

## Lenses

Each lens is one bounded worker owning a single dimension over the whole scope. It answers one question, returns evidence, and nothing else: it never edits the repository, never writes workflow state, and never decides what another lens should examine.

| Lens | Question it answers | Evidence it must return | Worker capability |
|---|---|---|---|
| `prior-art` | Has this already been solved or attempted here? | Prior audits and solution docs with exact covered paths and prior status | Repository-history and prior-solution research |
| `duplication` | Is one rule stated in more than one place? | Every copy's location, plus what makes them disagree today or soon | Pattern-recognition and semantic-equivalence review |
| `structure` | Does every resource have one owner and one caller path? | Orphaned files with a zero-inbound-reference search; duplicated ownership with each competing location | Architecture and ownership-boundary review |
| `maintainability` | What makes this scope expensive to change? | The complex or drift-prone surface with its cost, measured rather than asserted | Maintainability and complexity review |
| `tests` | Does the suite actually protect the stated behavior? | The untested path, the test that would cover it, and whether CI runs the covering suite | Test-coverage and verification review |
| `docs` | Do the documents describe the code as it is? | The claim, its location, and the contradicting code or command output | Documentation-accuracy review |
| `security` | Are inputs, secrets, and privileges handled at the boundary? | The unvalidated input path and how it reaches a sensitive sink | Security and trust-boundary review |
| `framework` | Does this scope fight its own framework's native practice? | The hand-rolled surface and the framework capability that supersedes it | Framework-native best-practice review |
| `synthesis` | Which findings are the same defect? | Merged reference surfaces, reconciled conflicts, and score justification | General-purpose synthesis over completed reports |

Select the closest host-native specialist where relevant. If none is available, use a general-purpose worker with the same evidence contract.

Select a subset when the scope makes a dimension irrelevant. Naming a lens no worker implements is a configuration error, not a silent no-op.

`security` findings are reported like any other, but a security control is a terminal exclusion from compound repair under the Safety and Evidence Invariants in `../SKILL.md`. The lens exists so the defect is visible, not so it is auto-repaired.

### A lens that cannot run

A lens that cannot run at all is recorded `blocked` with the reason and appears in the audit's coverage gaps. Never drop a lens silently: a narrower run must be visible as one, so the reader can see the shape of what was not examined.

### One defect, several lenses

Independent lenses observing one defect is itself evidence. Synthesis merges findings that share a normalized defect and the same locations into one finding, keeps the worst severity any lens assigned, keeps the leverage computed from the merged reference surface, and records every corroborating lens.

Merging only works when titles name the defect rather than the activity, so every worker writes titles by the rule in [audit.md](audit.md).

## Prior-art fallback

```text
SCOPE_ROOT: {{SCOPE_ROOT}}

Read relevant entries under docs/solutions/ and prior lean-refactor audits under docs/audits/. Do not search implementation for new findings.

Return PRIOR_ART_BRIEF with solved pattern, exact covered paths, skip guidance, and prior status. If absent, return `PRIOR_ART_BRIEF: No prior art found.`
```

## Universal layer-scan brief

Prepend to every layer prompt:

```text
SCOPE_ROOT: {{SCOPE_ROOT}}
LAYER_PATHS: {{LAYER_PATHS}}
REPO_FRAME_ARTIFACT: {{REPO_FRAME_ARTIFACT_OR_NONE}}
PRIOR_ART_BRIEF:
{{PRIOR_ART_BRIEF}}

Follow the canonical workflow and the Safety and Evidence Invariants in SKILL.md. Do not restate or weaken them.

Scan exhaustively; no top-N or word cap. Read complete relevant files. Enumerate complete reference surfaces required by SKILL.md, including dynamic/indirect references and persisted identifiers/stores. Do not infer completeness from a sample; an unqueryable relevant store is `blocked`.

If a repository-frame artifact exists, use it to route work before reading files. Prefer ready CodeGraph JSON queries for supported symbol/call/impact surfaces, CPD for clone candidates, `scc` for inventory, and `ast-grep` for structural searches. Record every invoked command and version. These accelerators never prove semantic equivalence or complete persisted/external-state coverage; use `rg` and domain-native store queries as required.

For every search, record reproducible provenance:
- exact command/query or tool query
- root and include/exclude filters
- match count
- files/stores inspected and timestamp/tool version
- exclusions and why
- full raw output or durable artifact path plus content hash

For each candidate, use canonical `evidence_state: confirmed | suspected | blocked` from SKILL.md. Syntactically similar but semantically different candidates are `suspected` with rejection rationale; incomplete evidence, unqueryable stores, or unresolved report conflicts are `blocked`. Only `confirmed` candidates become repair candidates; preserve all others in evidence appendix.

Semantic equivalence requires matching inputs, outputs, side effects, ordering, error behavior, lifecycle, security boundary, migration/state meaning, and consumer expectations. Literal similarity alone is insufficient.

Each confirmed finding must include:
- stable finding ID
- every `file:line` in complete reference surface
- current excerpts when each is under 8 lines
- proposed existing canonical SSOT, or evidence no existing location fits
- sites_affected literal count
- effort 1..4 and drift_hazard_severity 0..3
- severity P0..P3 scored by impact only, per references/ranking.md
- path classifications required by SKILL.md
- full search provenance and `evidence_state: confirmed`
- semantic-equivalence argument across canonical dimensions
- conservative state classification and store-query result
- baseline test/lint evidence available before repair

A finding affecting one site is still reported when its severity warrants it. Score it honestly and let ranking decide it is not compound; never inflate sites or drift to make it survive.

End with totals: confirmed, suspected, blocked, duplicated LOC, estimated reduction, drift hazards, legacy paths, temporary exceptions, and severity counts P0..P3. Name any surface you could not inspect and what stopped you. End with already-well-consolidated list.

Prefer fewer well-evidenced findings over a long list, and report the absence of findings honestly rather than padding.
```

## Layer prompt

```text
Apply universal layer-scan brief to {{LAYER_PATHS}}.

Hunt for duplicated registries/defaults, repeated consumer wiring, split read/write paths, unused shared helpers, literals representing one domain value, duplicated template/style fragments, lifecycle or error-handling drift, and comments requiring copies to stay synchronized.

Treat framework-specific patterns only as examples. Report only evidence-backed findings in this scope.
```

## Later cross-cutting synthesis

```text
SCOPE_ROOT: {{SCOPE_ROOT}}
INPUT_REPORTS: {{REPORT_PATHS_OR_FULL_REPORTS}}

All layer scans are complete. Follow the SKILL.md Execution Routing synthesis step and references/ranking.md. Do not search only for a presentation top-N and do not discard long-tail findings.

Merge complete reference surfaces, deduplicate by semantic source and affected sites, and reconcile conflicts by recording source reports, disagreement, decision, and supporting evidence; unresolved conflicts remain suspected/blocked. When several lenses observed one defect, keep the worst severity assigned and record every corroborating lens. Require semantic equivalence and justify every score component, severity, and tier. Flag shared-file boundaries. List every blocked lens and withheld claim as a coverage gap.

Produce exhaustive ranked findings and full provenance for audit persistence. Synthesis is the last shared stage: it produces the same artifact whether the run terminates at a review report or continues into approval, so do not tailor it to a depth.
```

## Generic slicing

1. Consumers: pages, components, handlers, widgets.
2. Shared infrastructure: registries, helpers, traits, services.
3. Assets and contracts: templates, CSS, JS, schemas, migrations, APIs.
4. Later synthesis across completed reports.

WordPress, Rails, React, Go, and Django names are examples only; prompts must use actual repository vocabulary.
