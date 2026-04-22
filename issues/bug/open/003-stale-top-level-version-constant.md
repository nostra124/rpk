---
id: BUG-003
type: bug
priority: low
status: open
---

# BUG-003: `VERSION='1.0.0'` at the top of `bin/rpk` is dead/stale

## Severity
Low — cosmetic. Misleads readers and trips up grep-based version
introspection tools.

## Observed
`bin/rpk:10` defines `VERSION='1.0.0'` as a top-level constant. The
real version source-of-truth is `.rpk/versions` (latest entry
`1.2.1`). Grepping for the current version lands on the stale
constant and returns `1.0.0`.

The only other reference to `$VERSION` in the script was the
`command:changelog` header bug (BUG-003 cousin: fixed as part of
commit `4907ba2`); the constant itself is no longer read anywhere.

## Root Cause
Vestige from before the ledger-based versioning model landed.

## Fix plan
Delete the `VERSION=` line. No callers remain. If external tooling
wants the version, the canonical source is `rpk rpk version` (or
`rpk rpk versions | tail -1` from inside the rpk worktree).

## Regression Protection
Add a bats test that greps `bin/rpk` for a top-level `VERSION=` line
outside a function scope and fails if one is reintroduced.
