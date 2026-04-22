# SIT — System Integration Tests

bats-based suites that exercise rpk end-to-end inside a fresh
containerised Linux distribution. Each suite builds its target image
on demand via the Dockerfiles under `podman/`, then runs rpk commands
inside `podman run --rm` containers.

## Prerequisites

- `podman` (>= 4.x)
- `bats` (same version used by the unit tier)

If `podman` is absent, `make check-sit` exits 0 with a skip message —
the tier is gated, not required.

## Running

    make check-sit

Invoke a single suite directly:

    bats tests/sit/suites/01_install.bats

## Adding a distro

1. Drop a `podman/Dockerfile.<distro>` that installs deps, copies the
   repo, runs `./configure && make install`, and ends with a
   smoke-test `RUN` (e.g. `rpk help | grep usage`).
2. In the suite, call `sit_build_image <distro>` in `setup_file`,
   then `sit_run <distro> <cmd>` per test.
3. Mirror the existing matrix in additional test cases (or add a
   parametrised suite if the list grows).

## Adding a suite

Number suite files `NN_topic.bats`. Current convention:

| #  | Topic                  | Purpose                                   |
|----|------------------------|-------------------------------------------|
| 01 | install                | rpk builds and installs on a fresh distro |
| 02 | lifecycle (planned)    | package → install → delete round-trip      |
| 03 | remote (planned)       | push/pull/release via ssh container        |
