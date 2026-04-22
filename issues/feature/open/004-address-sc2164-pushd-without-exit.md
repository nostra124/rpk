---
id: FEAT-004
type: feature
priority: medium
status: open
---

# Address SC2164 — `pushd`/`cd` without `|| exit` / `|| return`

## Description

**As a** maintainer
**I want** rpk to handle `pushd`/`cd` failures explicitly
**So that** a failed directory change doesn't silently leave the
function operating on the wrong cwd, which can turn into filesystem
damage (`rm -rf` against the parent), mis-targeted installs, or git
operations against the wrong repository.

Currently `.shellcheckrc` silences **61** SC2164 hits. That's the
biggest open category of shellcheck findings in the codebase.

## Implementation

Two realistic approaches; pick one:

**Option A — explicit guards per call site.** Change every
`pushd "$X" > /dev/null` to:

    pushd "$X" > /dev/null || fatal "cannot enter $X"

and every `cd "$X"` similarly. Re-enable SC2164 in `.shellcheckrc`.

**Option B — `set -e` at the top of `bin/rpk`.** Makes any failed
command fatal. Higher blast radius: requires auditing every `|| true`
and every test-style expression that intentionally tolerates failure.
More work up front but catches a broader class of errors.

Option A is incremental and preserves today's control flow. Option B
is architecturally cleaner. Recommend A for now.

## Acceptance Criteria

1. No `pushd` or `cd` call in `bin/rpk` or `.rpk/*` lacks an error
   handler.
2. `SC2164` removed from `.shellcheckrc` disabled list.
3. `make lint` passes at `--severity=warning` with SC2164 enabled.
4. All existing tests still green.
