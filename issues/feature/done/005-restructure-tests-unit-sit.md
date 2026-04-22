---
id: FEAT-005
type: feature
priority: medium
status: done
---

# Restructure tests into `unit/` and `sit/` tiers

## Description

**As a** maintainer
**I want** rpk's tests split into unit (fast, local) and SIT (system
integration, containerised, per-distro)
**So that** we can validate platform-specific behaviour — package
manager detection, native install flows, ssh-backed commands —
without polluting the fast per-push feedback loop.

Mirrors wyrd's `tests/{unit,sit,pit}` model at
`/Users/rene/Projekte/wyrd/tests/`. rpk doesn't need PIT (there's no
multi-node behaviour to stress), so the initial tiers are just `unit`
and `sit`.

This is a **prerequisite** for FEAT-006 (expand-platform-support) and
FEAT-007 (tests-for-push-pull-release).

## Implementation

Directory layout:

    tests/
    ├── README.md
    ├── unit/
    │   ├── helpers.bash             (moved from t/)
    │   ├── dispatcher.bats
    │   ├── init.bats
    │   ├── versions.bats
    │   ├── lifecycle.bats
    │   ├── stage.bats
    │   ├── dependency.bats
    │   ├── changelog.bats
    │   └── lint.bats
    └── sit/
        ├── README.md
        ├── podman/
        │   ├── Dockerfile.alpine
        │   ├── Dockerfile.debian
        │   ├── Dockerfile.fedora
        │   ├── Dockerfile.ubuntu
        │   └── Dockerfile.archlinux
        ├── helpers.bash
        └── suites/
            ├── 01_install.bats      (rpk builds, bundles, stows end-to-end)
            ├── 02_depends.bats      (`.rpk/depends/*` actually installs
            │                         the binary on that distro)
            └── 03_update.bats       (upgrade path picks the right
                                      package manager)

Retire the `t/` directory (leave a stub `t/README.md` pointing at
`tests/unit/`, or remove entirely once users have migrated).

Makefile targets:

| Target            | Runs                                                            |
|-------------------|-----------------------------------------------------------------|
| `make check`      | `make check -C tests/unit` (bats against `tests/unit/*.bats`)  |
| `make check-sit`  | builds `tests/sit/podman/*` images, runs `tests/sit/suites/*`   |
| `make check-all`  | both of the above                                               |
| `make test`       | alias for `make check` (backwards compatibility)                |

`make check` is the default for CI per-push; `make check-sit` runs
nightly or on explicit invocation. `make check-sit` fails cleanly if
`podman` isn't available.

## Acceptance Criteria

1. All current 55 bats tests live under `tests/unit/` and still pass
   via `make check`.
2. `make check-sit` builds at least one Dockerfile (e.g. alpine) and
   runs at least one SIT suite against it, asserting `make install`
   succeeds inside the container and `rpk rpk install` completes.
3. `make check-sit` soft-skips with a clear message if `podman` isn't
   installed (parity with how `lint` handles missing `shellcheck`).
4. `docs/PACKAGING.md` gains a "Testing your package" section
   referencing both tiers.
5. The CI workflow (or documented invocation) runs `make check` on
   every push and `make check-sit` on a schedule.
