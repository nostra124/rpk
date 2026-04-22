---
id: FEAT-003
type: feature
priority: low
status: done
---

# Extend `make lint` to cover `.rpk/*` scripts

## Description

**As a** maintainer
**I want** `make lint` to also shellcheck the scripts under `.rpk/`
(`package`, optional `install`, `delete`, everything under `depends/`)
**So that** portability bugs and quoting issues in the package scripts
are caught the same way they are for `bin/rpk`.

## Implementation

Update the `lint` target to include:

- `.rpk/package`
- `.rpk/install` (if present)
- `.rpk/delete` (if present)
- `.rpk/depends/*`

Still strict at `--severity=warning`, inheriting the project
`.shellcheckrc`.

Example:

    RPK_SCRIPTS := .rpk/package \
                   $(wildcard .rpk/install) \
                   $(wildcard .rpk/delete) \
                   $(wildcard .rpk/depends/*)
    lint:
        @shellcheck --severity=warning $(SCRIPTS) $(RPK_SCRIPTS)

Additionally, update `t/lint.bats` to assert the `.rpk/` scripts also
pass.

## Acceptance Criteria

1. `make lint` shellchecks `bin/rpk` and every `.rpk/` script.
2. All current `.rpk/*` scripts pass at `--severity=warning`.
3. `t/lint.bats` covers `.rpk/*` in the same test case or a sibling.
