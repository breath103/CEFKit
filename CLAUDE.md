# CLAUDE.md

Notes for agents working in this repo.

## Pre-PR health check (mandatory)

Before opening a pull request, run:

```
./scripts/lint.sh
```

This runs `swiftformat` (write) and `swiftlint --fix`, then a final `swiftlint`
pass to surface anything the autofixer couldn't handle. Commit any resulting
changes as part of the PR.

To verify without modifying files (mirrors what a future CI job would do):

```
./scripts/lint.sh check
```

Tools are assumed installed via Homebrew:

```
brew install swiftlint swiftformat
```

**CI does not run lint yet** — this contract is enforced by agents/humans,
not by the pipeline. If you see lint violations in `main`, they slipped past
the pre-PR step; fix them in the next PR.

Config lives at `.swiftlint.yml` and `.swiftformat` at the repo root.
The Objective-C++ shims under `Sources/ChromiumViewObjC` and the C++ wrapper
under `Sources/ChromiumWrapper` are excluded — they're not Swift.
