# lean-refactor

`lean-refactor` finds and fixes compound Single Source of Truth (SSOT) and Don't Repeat Yourself (DRY) violations. It targets consolidations where one canonical change removes drift across multiple files, call sites, modules, schemas, tests, or operational surfaces.

Don't use it for single-file cleanup, one-function bug fixes, new features, or cleanup limited to recent changes.

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
/lean-refactor [SCOPE] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

For iterative runs, use the coordinator entrypoint:

```sh
scripts/workflow.sh init [SCOPE] [--max-iterations N] [--tier-floor 1|2|3|4] [--code-only]
```

The coordinator writes local state, a discovery-checkpoint ledger, and a per-boundary ledger. Use its `discovery`, `approve`, `verify-approval`, `boundary`, `finalize`, `conclude-discovery`, `status`, and `cancel` commands for transitions. `conclude-discovery` is the zero-findings convergence path. Initialization doesn't register the continuation adapter; when the host supports stop hooks, register the absolute path to `scripts/event-stop.sh` and pass its documented JSON input. Without that adapter, runs are single-turn and must not claim automatic continuation.

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
