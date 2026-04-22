---
id: FEAT-002
type: feature
priority: low
status: done
---

# `rpk init` should commit AGENTS.md alongside `.rpk/`

## Description

**As a** package author
**I want** `rpk init` to stage and commit the `AGENTS.md` stub it
creates, the same way it does for `.rpk/`
**So that** agents cloning the repository fresh pick up the agent
scaffold guidance without an extra manual commit step.

## Implementation

In `command:init`, after writing `AGENTS.md`, include it in the same
commit that stages `.rpk/`:

    git add .$SELF AGENTS.md
    if git diff --cached --quiet -- .$SELF AGENTS.md; then
        info "no changes to commit"
    else
        git commit -m "initialized .$SELF + AGENTS.md" .$SELF AGENTS.md ...
    fi

Keep it idempotent: if the user already has a committed `AGENTS.md`
and the stub isn't written (because `[ ! -f ]` skipped the write),
`git add AGENTS.md` stages nothing new and the commit is skipped.

## Acceptance Criteria

1. `rpk init` on a fresh repo produces one commit containing both
   `.rpk/` and `AGENTS.md`.
2. If `AGENTS.md` already existed (user-authored), `rpk init` leaves
   it alone — no overwrite, and no spurious commit.
3. `t/init.bats` gains a test asserting `AGENTS.md` is tracked after
   init.
