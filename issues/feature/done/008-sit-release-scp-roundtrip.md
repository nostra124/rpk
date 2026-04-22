---
id: FEAT-008
type: feature
priority: low
status: done
---

# SIT coverage for `rpk release` scp + remote `update` round-trip

## Description

**As a** maintainer
**I want** `rpk <pkg> release <account>` exercised end-to-end against a
real ssh endpoint — including the scp-the-current-rpk-script step and
the subsequent `ssh <account> "/tmp/rpk <pkg> update"` invocation
**So that** regressions in that "upload + remote-trigger" path are
caught in CI rather than surfacing when someone actually releases a
package.

Deferred from **FEAT-007**: the current remote SIT suite exercises
push/pull/drop but not release, because release needs to distinguish
"the rpk that got scp-ed over" from "an already-installed rpk on the
remote" — a single-container setup (where both users share
/usr/local/bin/rpk) can't make that distinction.

## Implementation

Two possible approaches; pick one.

### (a) Two separate containers

Add `Dockerfile.ssh-upstream` (rpk installed) and
`Dockerfile.ssh-receiver` (no rpk, only ssh server + stow + git).
Network them via a podman pod or shared podman network so the
upstream container can ssh to the receiver.

release should:
1. scp rpk binary to `/tmp/rpk` on the receiver
2. run `ssh receiver /tmp/rpk <pkg> update` there
3. verify an installed binary appears under the receiver's target

Test asserts:
- `/tmp/rpk` was scp-ed (check mtime, checksum)
- the package was installed on the receiver (`/usr/local/bin/hello-<pkg>`
  or similar, depending on the buildable fixture)

### (b) Single container with user-local rpk

Keep one container. Install rpk globally as today, but inject a
sentinel `RPK_MARKER=system` into the system copy and rely on the
scp'd `/tmp/rpk` having no marker (or a different marker). The test
verifies that release used `/tmp/rpk` and not the system one by
inspecting a log file the scp'd script writes.

More fragile than (a) but avoids the two-container networking.

## Acceptance Criteria

1. SIT suite (e.g. `tests/sit/suites/04_release.bats`) exercises
   `rpk <pkg> release <account>` end-to-end.
2. Test asserts the scp step actually transferred the current rpk
   binary to `/tmp/rpk` on the remote.
3. Test asserts `ssh <account> "/tmp/rpk <pkg> update"` succeeded and
   produced the expected installed artefact on the remote side.
4. Suite soft-skips when podman is absent, same pattern as the rest
   of the tier.
