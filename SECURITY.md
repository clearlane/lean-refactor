# Security Policy

## Supported versions

Only the latest revision on `main` receives security fixes.

## Reporting a vulnerability

Report vulnerabilities privately through GitHub Security Advisories for `clearlane/lean-refactor`. If advisories are unavailable, use Clearlane's private organization contact channel.

Don't disclose vulnerabilities in public issues, discussions, pull requests, or social channels. Include affected files, reproduction steps, impact, and any suggested fix. Maintainers will confirm receipt and coordinate disclosure after a fix is available.

## Trust boundary

Run this skill only from a trusted checkout. Scripts don't need `sudo` and shouldn't be run with elevated privileges. Before each run, review the resolved target root and requested scope. Treat target repository files, hooks, build commands, and agent instructions as trusted inputs only after inspection.
