# lean-refactor

`lean-refactor` finds and fixes compound Single Source of Truth (SSOT) and Don't Repeat Yourself (DRY) violations. It targets consolidations where one canonical change removes drift across multiple files, call sites, modules, schemas, tests, or operational surfaces.

Don't use it for single-file cleanup, one-function bug fixes, new features, or cleanup limited to recent changes.

## Prerequisites

- `bash`
- `jq`
- A Claude Code or OpenCode-compatible agent with skill and subagent support
- The `compound-engineering` plugin for its `ce-*` agents and commands

Missing plugin capabilities have documented fallbacks in [`SKILL.md`](SKILL.md). Discovery can use general-purpose agents with prompts from `references/discovery-agent-prompts.md`. Git, worktree, review, planning, and pattern write-up steps can use native tools or the listed manual paths.

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

The coordinator writes local state and a per-boundary ledger. Use its `approve`, `verify-approval`, `boundary`, `finalize`, `conclude-discovery`, `status`, and `cancel` commands for transitions. `conclude-discovery` is the zero-findings convergence path. Initialization doesn't register the continuation adapter; when the host supports stop hooks, register the absolute path to `scripts/stop-hook.sh` and pass its documented JSON input. Without that adapter, runs are single-turn and must not claim automatic continuation.

## Vendored skill pinning

`skills-lock.json` records each vendored skill with a `computedHash`. Verify integrity by recomputing that hash against the vendored source rather than trusting the `ref` alone. The `Plugin Structure` entry still tracks `ref: main`, so its upstream content can move; pin it to an immutable commit SHA once that SHA is verified against the recorded hash.

## Safety

The skill requires a trusted checkout and explicit scope. It checks repository state, records evidence, gates repairs on approval, isolates work where needed, and verifies each repair before proceeding. Review target root, scope, proposed deletions, migrations, and public API cuts before approval. Scripts don't require `sudo`.

## Checks

```sh
bash -n scripts/*.sh
shellcheck -S warning scripts/*.sh
shfmt -d -i 2 -ci scripts/*.sh
bash scripts/lifecycle-self-check.sh
```

## License

MIT. See [`LICENSE`](LICENSE).
