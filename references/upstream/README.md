# Absorbed Sources

One file per absorbed source, so provenance scales by adding a file rather than
by growing a single registry that every future absorption must edit.

| Source | Absorbed on | Record |
|---|---|---|
| `repo-review` | 2026-08-03 | [repo-review.md](repo-review.md) |

Each record carries the source location, baseline digest, absorption date, and
bound plan hash, followed by what was absorbed, what was deliberately excluded
and why, and the canonical destinations that now own the behavior.

## Refreshing a Source

When an absorbed source changes upstream, compare the changed tree against the
baseline digest in its record, then run the absorption workflow again with a
fresh snapshot and this skill as target. Update that source's record with the
new baseline, date, plan hash, and any newly retained or excluded capability.

A source with no upstream cannot be refreshed. Its record is a historical
account of where the behavior came from, not a tracking entry.
