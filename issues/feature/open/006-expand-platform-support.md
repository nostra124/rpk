---
id: FEAT-006
type: feature
priority: medium
status: open
depends-on: FEAT-005
---

# Expand platform support in `command:platform` and `command:upgrade`

## Description

**As a** user on a Linux distro that isn't Debian-family or macOS
**I want** rpk to detect my platform and use the right native package
manager when I run `rpk upgrade` or `rpk <pkg> depends`
**So that** installing rpk and its prerequisites works on Fedora,
Arch, Alpine, openSUSE, Homebrew-on-macOS, etc., without me hand-rolling
`.rpk/depends/*` scripts per machine.

Depends on **FEAT-005** (test-restructure): without SIT coverage we
can't verify the new platform branches against real distro images.

## Implementation

Two coordinated changes:

### `command:platform`

Currently detects: `macos`, `linux`, `synology`, and Linux distro via
`/etc/os-release`'s `ID=`. Reliable for debian/ubuntu/fedora/alpine on
those inputs, but the downstream `command:upgrade` only acts on
`debian|ubuntu|pureos|macos`, silently no-ops elsewhere.

Extend with:

- `alpine` — `apk` (no longer empty-case)
- `fedora`, `rhel`, `centos`, `rocky`, `almalinux` — `dnf` / `yum`
- `arch`, `manjaro` — `pacman`
- `opensuse`, `opensuse-leap`, `opensuse-tumbleweed`, `sles` — `zypper`
- `gentoo` — `emerge`
- `freebsd` (from `uname -s`) — `pkg`
- macOS + Homebrew — detect `brew` when `port` isn't present
- macOS + MacPorts — already handled via `/opt/local/bin/port`

### `command:upgrade`

Add a branch per detected platform with the appropriate update /
upgrade invocation and the minimal `rpk`-required prereqs (`git`,
`rsync`, `stow`, `bats`, `shellcheck`).

### Dependency scaffolds

Update `.rpk/depends/*` scripts in this repo to fall through the new
platform cases; update the cookbook in `docs/PACKAGING.md` and the
depends template that `rpk-author` documents.

## Acceptance Criteria

1. `command:platform` returns a stable identifier per distro family
   for at least: alpine, arch, debian, fedora, opensuse, ubuntu,
   macos-ports, macos-brew, freebsd.
2. `command:upgrade` has a branch for each, invoking the right
   native upgrade command and installing missing `git` / `rsync` /
   `stow`.
3. Every `.rpk/depends/*` script in this repo handles the same set.
4. SIT suite under `tests/sit/suites/` validates install+upgrade
   against at least alpine, debian, fedora, and arch Dockerfiles.
5. `docs/PACKAGING.md`'s depends cookbook documents the same matrix
   (single per-platform branch pattern) so agent-generated scripts
   match.
