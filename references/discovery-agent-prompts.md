# Discovery Agent Prompts

Templates supplement canonical workflow in `../SKILL.md`; they do not redefine approval, hard-cut, scheduling, or persistence policy.

## Dispatch contract

Run prior-art discovery first. After it returns, dispatch all layer scans in one parallel batch. Run cross-cutting synthesis **later**, after every layer report exists; give it complete reports or staged `master.md`. Never run synthesis in parallel with scans it must synthesize.

Recommended specialists:

| Lens | `subagent_type` |
|---|---|
| Prior art | `compound-engineering:ce-learnings-researcher` |
| Pattern duplication | `compound-engineering:ce-pattern-recognition-specialist` |
| Maintainability | `compound-engineering:ce-maintainability-reviewer` |
| Architecture | `compound-engineering:ce-architecture-strategist` |
| Framework practice | `compound-engineering:ce-best-practices-researcher` |
| Cross-cutting synthesis | `general-purpose` |

Use matching domain reviewer from `SKILL.md` where relevant. If specialist is unavailable, use `general-purpose` with same evidence contract.

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
PRIOR_ART_BRIEF:
{{PRIOR_ART_BRIEF}}

Follow canonical workflow and Hard-Cut Policy in SKILL.md. Do not restate or weaken them.

Scan exhaustively; no top-N or word cap. Read complete relevant files. Enumerate complete reference surfaces required by SKILL.md, including dynamic/indirect references and persisted identifiers/stores. Do not infer completeness from a sample; an unqueryable relevant store is `blocked`.

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
- path classifications required by SKILL.md
- full search provenance and `evidence_state: confirmed`
- semantic-equivalence argument across canonical dimensions
- conservative state classification and store-query result
- baseline test/lint evidence available before repair

End with totals: confirmed, suspected, blocked, duplicated LOC, estimated reduction, drift hazards, legacy paths, temporary exceptions. End with already-well-consolidated list.
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

All layer scans are complete. Follow SKILL.md Phase 3 and references/ranking-rubric.md. Do not search only for a presentation top-N and do not discard long-tail findings.

Merge complete reference surfaces, deduplicate by semantic source and affected sites, and reconcile conflicts by recording source reports, disagreement, decision, and supporting evidence; unresolved conflicts remain suspected/blocked. Require semantic equivalence and justify every score component/tier. Flag shared-file boundaries. Produce exhaustive ranked findings and full provenance for audit persistence, or complete inline audit when SKILL.md selected read-only discovery.
```

## Generic slicing

1. Consumers: pages, components, handlers, widgets.
2. Shared infrastructure: registries, helpers, traits, services.
3. Assets and contracts: templates, CSS, JS, schemas, migrations, APIs.
4. Later synthesis across completed reports.

WordPress, Rails, React, Go, and Django names are examples only; prompts must use actual repository vocabulary.
