# rpk — A Bash-Based Package Manager

rpk is a small, bash-only package manager that treats git repositories as
packages. It provides semver-based version management, per-package
dependency scripts, and GNU-Stow-backed installation into either the
user's `~/.local` or the system's `/usr/local`. Packages can be pushed
to, pulled from, and released across remote SSH accounts.

## Features

- **Git-based packages** — every package is a git repository with a
  `.rpk/` directory describing how to version, build, and install it.
- **Semver ledger** — a `.rpk/versions` file (`<semver><TAB><commit-sha>`)
  records what each version points at; `rpk <pkg> major/minor/patch`
  extends it.
- **GNU Stow installs** — per-version bundles under `~/.local/pkg/` are
  symlinked into `~/.local/` via `stow`; uninstall reverses the links.
- **Cross-distro platform detection** — recognises alpine, arch, debian,
  fedora, freebsd, linuxmint, macos (macports + homebrew), manjaro,
  opensuse, rhel, synology, ubuntu, and more (see `rpk platform`).
- **Remote synchronisation** — `push`, `pull`, `release`, `sync`, `drop`
  over SSH; release scp's the rpk binary and triggers a remote update.
- **Bash completion + man page** — shipped via `make install`.
- **Agent integration** — bundled `rpk-author` skill for Claude Code,
  opencode, and raven helps agents convert arbitrary git repos into rpk
  packages. See [docs/PACKAGING.md](docs/PACKAGING.md).

## Installation

### One-line bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/nostra124/rpk/master/install | bash
```

Installs to `$HOME/.local` by default. Override with env or flags:

```bash
# Custom prefix
curl -fsSL https://raw.githubusercontent.com/nostra124/rpk/master/install \
  | bash -s -- --prefix=/opt/rpk
```

Prerequisites the script checks for: `git`, `make`. `stow`, `rsync`, and
`git` must also be present at runtime for rpk to install packages.

### From a checkout

```bash
git clone https://github.com/nostra124/rpk.git
cd rpk
./install                       # same flags: --prefix, --repo, --branch
# or
./configure --prefix=$HOME/.local
make install
```

`make install` drops:

- `bin/rpk` — main executable (symlink into `$INSTALL_BIN`)
- `etc/bash_completion.d/rpk`
- `share/man/man1/rpk.1`
- `share/doc/rpk/PACKAGING.md` — authoring guide for rpk packages
- `share/claude/skills/rpk-author/SKILL.md` — Claude Code skill
- `share/raven/skills/rpk-author/SKILL.md` — Raven skill
- `share/opencode/commands/rpk-author.md` — opencode command

Opt-in agent activation (only touches agent dirs that already exist):

```bash
make install-skills-user
```

## Quick Start

```bash
# Show help
rpk help

# In a git repo, scaffold the .rpk/ layout and AGENTS.md stub
cd my-package
rpk init

# Record a new version against current HEAD
rpk my-package patch          # -> <prev>.<prev>.<prev+1>

# List visible packages
rpk list

# Stage a package (clone from its bare repo in $XDG_DATA_HOME/repo)
rpk my-package stage

# Install latest version
rpk my-package install

# Update (stage + reinstall latest)
rpk my-package update
```

**All package operations follow the form `rpk <package> <command>
[args]`**, with the package first. Non-package commands (`help`, `list`,
`platform`, `upgrade`, etc.) take no package prefix.

## Package Structure

A valid rpk package is a git repository with:

```
my-package/
├── .rpk/
│   ├── type             # "user" or "system"
│   ├── versions         # version ledger (one per line: <semver>\t<sha>)
│   ├── package          # executable that builds a bundle for a given version
│   ├── install          # optional post-install hook
│   ├── delete           # optional pre-delete hook
│   ├── identity         # optional explicit package name override
│   └── depends/         # one executable per prerequisite (bash, git, stow, …)
├── AGENTS.md            # optional stub scaffolded by `rpk init`
├── bin/ · etc/ · share/ # payload installed into the target prefix
└── command/             # optional per-package subcommands (rpk <pkg> <cmd>)
```

Full reference (contract for every file, build-system cookbook, agent
playbook for converting upstream repos): **[docs/PACKAGING.md](docs/PACKAGING.md)**
(also installed at `$(rpk source)/../share/doc/rpk/PACKAGING.md`).

### Minimal `.rpk/package`

```bash
#!/bin/bash
function die() { echo "$@"; exit 100; }

PACKAGE=$(rpk identity)
VERSION=$1
test -z "$VERSION" && VERSION=$(rpk versions | tail -1)

COMMIT=$(rpk commit "$VERSION")
test -z "$COMMIT" && die "version $VERSION has no commit hash"

TARGET=$(rpk bundle "$(rpk type)")/$PACKAGE-$VERSION
BRANCH=$(git branch --show-current)
trap 'git checkout "$BRANCH" --force' EXIT

git config advice.detachedHead false
git checkout "$COMMIT" || die "failed to checkout $COMMIT"

./configure --prefix="$TARGET"
make
make install

git checkout "$BRANCH" --force
```

### Platform-aware `.rpk/depends/*`

```bash
#!/bin/bash
BIN="make"
command -v "$BIN" > /dev/null 2>&1 && exit 0

case "$(rpk platform)" in
    alpine)                                          rpk action sudo apk add make ;;
    debian|ubuntu|pureos|linuxmint)                  rpk action sudo apt-get --yes install make ;;
    fedora|rhel|centos|rocky|almalinux)              rpk action sudo dnf install -y make ;;
    arch|manjaro|endeavouros)                        rpk action sudo pacman -S --noconfirm make ;;
    opensuse|opensuse-leap|opensuse-tumbleweed|sles) rpk action sudo zypper install -y make ;;
    freebsd)                                         rpk action sudo pkg install -y make ;;
    macos-ports)                                     rpk action sudo port install make ;;
    macos-brew)                                      rpk action brew install make ;;
    *)                                               echo "no packager for $(rpk platform)" >&2; exit 1 ;;
esac
```

## Commands

### Global options

| Flag | Meaning |
|---|---|
| `-d` | enable debug (`set -vx`); env equivalent `SELF_DEBUG=1` |
| `-v` | verbose output |
| `-q` | quiet mode (suppress `info`) |
| `-f` | force (e.g. re-package a version whose bundle already exists) |

### Information

| Command | Description |
|---|---|
| `help [<command>]` | top-level help, or per-command help |
| `source` | `$SELF_SOURCES` (`~/.local/src`) |
| `repo` | bare-repo directory (`$XDG_DATA_HOME/repo`) |
| `target <home\|system>` | install target directory |
| `bundle <home\|system>` | bundle staging directory |
| `list` | enumerate available packages |
| `platform` | detected platform identifier |

### Package-scoped (prefix: `rpk <pkg>`)

| Command | Description |
|---|---|
| `identity` | print the resolved package name |
| `version` | currently installed version |
| `versions` | every version declared in `.rpk/versions` |
| `major` / `minor` / `patch` | record a new version against HEAD |
| `changelog [version]` | GNU-style changelog between the given version and the previous one |
| `type` | `user` or `system` |
| `show` | summary (name, worktree, dependencies, versions, type) |
| `accounts` | SSH accounts configured for this package |
| `stage` | clone the bare repo into `$SELF_SOURCES`, or pull updates |
| `pull [accounts…]` | fetch + merge from local bare + listed accounts |
| `push [accounts…]` | push to local bare + listed accounts (creates remote bare if missing) |
| `release [accounts…]` | push, scp rpk to `/tmp/rpk` on each remote, trigger remote `update` |
| `sync [account]` | bidirectional fetch-merge-push against one account (or all known) |
| `drop <account>` | remove the named remote |
| `depends` | run every script under `.rpk/depends/` |
| `package [version]` | build the bundle at `$(rpk bundle <type>)/<pkg>-<version>` |
| `install [version]` | ensure bundle exists, stow into target, record installed version |
| `bundles` | list bundles already built |
| `cleanup` | remove bundles other than the installed version |
| `update` | stage + install latest version |
| `delete` | stow --delete every bundle, drop install record |
| `commands` | list package-local subcommands under `<worktree>/command/` |

### System

| Command | Description |
|---|---|
| `init` | scaffold `.rpk/` in the current git worktree + create the local bare repo |
| `upgrade` | upgrade the base OS via its native package manager (apt/dnf/pacman/zypper/apk/brew/port/pkg) |

## Agent integration

`make install` ships the `rpk-author` skill to three share paths:

| Agent | Installed at | Activation |
|---|---|---|
| Claude Code | `$INSTALL_SHARE/claude/skills/rpk-author/SKILL.md` | `ln -sf … ~/.claude/skills/rpk-author` |
| Raven | `$INSTALL_SHARE/raven/skills/rpk-author/SKILL.md` | `ln -sf … ~/.raven/workspace/skills/rpk-author` |
| opencode | `$INSTALL_SHARE/opencode/commands/rpk-author.md` | `ln -sf … ~/.config/opencode/commands/rpk-author.md` |

`make install-skills-user` performs the symlinking automatically for any
user config dir that already exists. `make uninstall-skills-user`
reverses it.

## Configuration

rpk honours the XDG Base Directory specification:

| Variable | Default (non-root) | Default (root) |
|---|---|---|
| `XDG_CONFIG_HOME` | `$HOME/.local/etc` | `/etc` |
| `XDG_DATA_HOME` | `$HOME/.local/var/lib` | `/var/lib` |

Derived paths:

| Name | Location |
|---|---|
| `$SELF_CONFIG` | `$XDG_CONFIG_HOME/rpk` |
| `$SELF_DATA` | `$XDG_DATA_HOME/rpk` (install records) |
| `$SELF_SOURCES` | `$HOME/.local/src` (staged package worktrees) |
| `$SELF_REPO` | `$XDG_DATA_HOME/repo` (local bare repos) |

## Development

rpk's own test suite has two tiers, both [bats](https://bats-core.readthedocs.io/)-based:

| Tier | Path | Scope |
|---|---|---|
| Unit | `tests/unit/*.bats` | Fast, sandboxed (per-test temp `$HOME`, XDG vars cleared). Covers dispatcher, init, versions, staging, dependencies, changelog, lifecycle, Makefile, shellcheck. |
| SIT | `tests/sit/suites/*.bats` | Podman-based. Builds per-distro Dockerfiles and runs rpk end-to-end inside each. Covers install on alpine/debian/fedora/arch, push/pull/drop against a real sshd, and release's scp + remote-update round-trip. |

```bash
make check                # unit tier (bats)
make check-sit            # SIT tier (bats + podman, auto-skips if podman missing)
make lint                 # shellcheck at --severity=warning
make all                  # lint + check
```

Both tiers use a sandboxed `$HOME` per test — they never touch your
real `~/.local/` or agent config dirs.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | general fatal error (`fatal` helper) |
| 2 | unknown command name (from `help <cmd>`) |
| 3 | no per-command help registered |
| 100 | failure from a package-provided `.rpk/` script (`die`) |

## Examples

### Authoring a new package from scratch

```bash
git init my-tool
cd my-tool
echo "hello" > README.md
git add README.md && git commit -m "initial"

rpk init                  # scaffolds .rpk/ + AGENTS.md, commits them
# edit .rpk/package + add depends under .rpk/depends/
rpk my-tool patch         # record 0.0.2 against current HEAD
rpk my-tool install       # build bundle, stow into target
```

### Installing a package from a remote account

```bash
# Pull the whole package from an ssh-reachable account that has rpk
rpk my-tool sync user@host

# Stage locally (clone from the now-available bare)
rpk my-tool stage

# Install
rpk my-tool install
```

### Updating an installed package

```bash
# Pull latest + reinstall latest version for a single package
rpk my-tool update

# Same for every package on the machine
rpk update
```

### Releasing a new version to a remote

```bash
# Bump version, then deploy end-to-end to the account:
# push bare, scp rpk binary, trigger remote `rpk my-tool update`.
rpk my-tool patch
rpk my-tool release user@host
```

## See also

- `man rpk` — full CLI reference
- [docs/PACKAGING.md](docs/PACKAGING.md) — authoring guide
  (`.rpk/` contract, build-system cookbook, agent playbook)
- [AGENTS.md](AGENTS.md) — operational notes for agents working on rpk itself

## License

See the project repository for license information.
