# lean-refactor

`lean-refactor` reviews a repository and fixes what it finds. One evidence-gated workflow runs at two depths:

- `--depth review` — read-only. Discovers, ranks by severity, publishes one report with an explicit coverage-gaps section, and terminates. It can never acquire approval.
- `--depth refactor` — the default. Continues past the report into approved, isolated repair of compound Single Source of Truth (SSOT) and Don't Repeat Yourself (DRY) violations, where one canonical change removes drift across multiple files, call sites, modules, schemas, tests, or operational surfaces.

Both depths share the same discovery spine — frame, prior art, parallel lenses, synthesis, audit — and diverge only after the audit is ready. Depth is orthogonal to backing (`--code-only`): depth decides where the run stops, backing decides what isolation guarantees mutation has.

Every confirmed finding carries two scores. `severity` (P0–P3) is impact and ranks the review; `leverage` (sites × drift / effort) is compound value and tiers the repair. A single-site defect that breaks a stated guarantee is `P0` and untiered — it leads the report without becoming compound repair work.

Don't use it for single-file review or cleanup, diff-only review, one-function bug fixes, new features, or cleanup limited to recent changes.

## Prerequisites

- `bash`
- `jq`
- An agent runtime with skill discovery, bounded worker delegation, and local command execution

Optional discovery accelerators are CodeGraph, `scc`, `jscpd`/`cpd`, and `ast-grep`. The skill feature-detects them; they are not required for correctness or resumability.

Durable run state is written to `<root>/.claude/` by default. Hosts that use a
different convention set `LEAN_REFACTOR_STATE_DIR` to a single path segment
before invoking the coordinator; keep it stable for the life of a run.

Development checks additionally use Bats and `check-jsonschema`. Runtime paths retain portable smoke-test and `jq` validation fallbacks; CI sets `LEAN_REFACTOR_STRICT_SCHEMA=1` to run full JSON Schema validation. Set `LEAN_REFACTOR_USE_YQ=1` to opt into structural YAML front-matter reads and updates when `yq` is available.

Missing specialist capabilities have documented fallbacks in [`SKILL.md`](SKILL.md). Discovery can use general-purpose workers with prompts from `references/worker-discovery.md`. Git, worktree, review, planning, and pattern write-up steps can use native tools or the listed manual paths.

## Install

Copy this repository into a supported skill directory:

```sh
cp -R lean-refactor ~/.claude/skills/lean-refactor
# or
cp -R lean-refactor ~/.agents/skills/lean-refactor
```

Restart or reload the agent so it discovers `SKILL.md`.

## Use

Invoke with a repository or scoped directory:

```text
/lean-refactor [SCOPE] [--depth review|refactor] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

For iterative runs, use the coordinator entrypoint:

```sh
scripts/workflow.sh init [SCOPE] [--depth review|refactor] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

The coordinator writes local state, a discovery-checkpoint ledger, and a per-boundary ledger. Use its `discovery`, `report`, `approve`, `verify-approval`, `boundary`, `finalize`, `conclude-discovery`, `status`, and `cancel` commands for transitions. `report` is the review terminal and moves the run to `reported`; `conclude-discovery` is the zero-findings convergence path for a refactor run. Initialization doesn't register the continuation adapter; when the host supports stop hooks, register the absolute path to `scripts/event-stop.sh` and pass its documented JSON input. Without that adapter, runs are single-turn and must not claim automatic continuation.

Before layer discovery, create a compact deterministic repository frame:

```sh
scripts/repo-frame.sh . --output /tmp/repo-frame.json
```

Use `--run-cpd` to include a compact clone-candidate report when `jscpd`/`cpd` is installed.

The frame reuses a ready CodeGraph index and records any available `scc`, CPD, and `ast-grep` implementations. Pass `--init-codegraph` only when creating or updating the local `.codegraph/` index is explicitly intended.

## Attribution

Skill packaging conventions draw on the `plugin-structure` skill from
[anthropics/claude-code](https://github.com/anthropics/claude-code). No upstream
file is vendored into this repository, so there is nothing to pin or hash-verify.

Skills absorbed into this one are recorded individually under
[`references/upstream/`](references/upstream/README.md), one file per source,
each with its baseline digest, absorption date, bound plan hash, absorbed
capabilities, and deliberate exclusions.

## Safety

The skill requires a trusted checkout and explicit scope. It checks repository state, records evidence, gates repairs on approval, isolates work where needed, and verifies each repair before proceeding. Review target root, scope, proposed deletions, migrations, and public API cuts before approval. Scripts don't require `sudo`.

## Checks

Run the complete check list through one entrypoint:

```sh
bash scripts/check.sh
```

It runs shell syntax, ShellCheck, `shfmt`, the filename convention, the Bats
lifecycle suite, and schema plus repository-frame validation. Missing optional
checkers are reported as `skip` locally. CI runs `scripts/check.sh --strict`,
which requires every checker and enables full JSON Schema validation.

## License

MIT. See [`LICENSE`](LICENSE).
