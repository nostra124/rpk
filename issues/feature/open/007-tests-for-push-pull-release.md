---
id: FEAT-007
type: feature
priority: medium
status: open
depends-on: FEAT-005
---

# Bats coverage for `push` / `pull` / `release` / `sync` / `drop`

## Description

**As a** maintainer
**I want** the network-facing commands exercised end-to-end against
a real ssh target
**So that** refactors of `ensure-remote` / `push:branches` / the
account-validation paths are caught by tests instead of surfacing in
production against the user's actual bare repos.

These commands currently have **no test coverage** — they're the only
ones in the rpk dispatcher with that status after FEAT-005 lands.

Depends on **FEAT-005** (test-restructure): ssh-backed tests need a
containerised ssh endpoint, which only makes sense in the SIT tier.

## Implementation

Under `tests/sit/suites/`:

- Start a container with `sshd` listening on a known port and
  passwordless key auth for a test user.
- Export ssh config so `ssh <account>` resolves to the container.
- Run tests that exercise:
  - `rpk <pkg> push <account>` — creates the remote bare if missing;
    pushes branches and tags.
  - `rpk <pkg> pull <account>` — fetches and merges from remote bare.
  - `rpk <pkg> release <account>` — push + scp rpk + `ssh rpk <pkg>
    update` round-trips cleanly.
  - `rpk <pkg> sync <account>` — bidirectional fetch/merge/push.
  - `rpk <pkg> drop <account>` — removes the remote cleanly.

A helper in `tests/sit/helpers.bash` brings up the ssh container,
seeds `$SELF_CONFIG/ssh/<account>.pub`, and tears down afterwards.

## Acceptance Criteria

1. New SIT suite `tests/sit/suites/04_remote.bats` exercises all five
   commands against a throwaway ssh container.
2. Suite skips cleanly when `podman` isn't available (same pattern as
   the rest of SIT).
3. Tests cover the "remote bare doesn't exist yet" branch of
   `command:push` (auto-create on first push).
4. `command:release`'s `/tmp/rpk <pkg> update` remote invocation is
   verified.
5. `command:drop` leaves other remotes untouched.
