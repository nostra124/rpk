---
id: BUG-001
type: bug
priority: medium
status: open
---

# BUG-001: `.rpk/versions` entries without commit SHAs are unusable

## Severity
Medium — `rpk rpk package <V>` and `rpk rpk changelog <V>` fatal for
every such entry, so those versions cannot be reproduced or installed.

## Observed
In this repo's `.rpk/versions`:

- Lines 1–16 (`1.0.0` through `1.0.15`) have only a version column, no
  commit SHA.
- Line 17 has `1.0.16\tx` — a literal `x` where the SHA should be.
- Lines 18–20 (`1.1.0`, `1.2.0`, `1.2.1`) are correctly formed.

`command:commit <V>` returns empty for the broken rows; `command:package`
then `die`s with `version X has no commit hash`. `command:changelog`
cannot compute a range when either endpoint has no SHA.

## Root Cause
Historical entries were written manually before the version-bump
commands consistently appended `<semver>\t<commit-sha>`. Line 17 is
either a typo or a placeholder that slipped in.

## Fix plan
1. Reconstruct SHAs for lines 1–16 if possible (walk `git log`,
   match each `"updated version to X"` commit subject to its version
   entry).
2. For entries with no recoverable SHA, either
   - delete the row (loses the ability to target that version), or
   - leave it but document in `docs/PACKAGING.md` that legacy entries
     are not packageable.
3. Fix line 17's `x` placeholder (resolve to the correct SHA or drop).

## Regression Protection
Add a bats test under `t/versions.bats` that walks `.rpk/versions` and
asserts every non-blank line either starts with `#` or has a tab and a
40-char hex commit SHA in field 2.
