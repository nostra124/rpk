# Packaging with rpk

This document describes how to turn a git repository into an rpk package.
It is the authoritative reference for the contract between an rpk package
and the `rpk` tool. Agents tasked with creating packages for arbitrary
repositories should read this file end-to-end before acting.

For usage of the `rpk` CLI itself, see `rpk(1)`.

## Concepts

An **rpk package** is a git repository whose root contains a `.rpk/`
directory describing how to build and install it.

A **bundle** is a versioned per-package tree under `$(rpk bundle <type>)/`
(defaults: `~/.local/pkg/` for user packages, `/usr/local/pkg/` for system
packages). Bundles are named `<package>-<version>`. Building a bundle
means populating that directory with a file tree that looks like an
install prefix (`bin/`, `etc/`, `lib/`, `share/`, …).

A **target** is where bundles get installed. `$(rpk target <type>)`
(defaults: `~/.local/` for user, `/usr/local/` for system).

Installation uses **GNU Stow**: once a bundle exists,
`stow --target=<target> <package>-<version>` symlinks every file inside
the bundle tree into the corresponding place in the target tree.
Uninstall reverses the symlinks.

## Anatomy of `.rpk/`

```
.rpk/
├── type              (file)   — "user" or "system"
├── versions          (file)   — the version ledger
├── package           (exec)   — builds a bundle for a given version
├── install           (exec)   — optional post-install hook
├── delete            (exec)   — optional pre-delete hook
├── identity          (file)   — optional package-name override
└── depends/          (dir)    — prerequisite scripts, one per dep
    ├── make
    ├── git
    └── …
```

### `.rpk/type`

Single line: `user` or `system`.

- `user` packages install into `$HOME/.local/` without privileges.
- `system` packages install into `/usr/local/` and require root.

### `.rpk/versions`

Append-only ledger. One line per version:

```
<semver><TAB><commit-sha>
```

Earliest version first. Example:

```
1.0.0	7e9647fabc…
1.1.0	2689bc7b5d…
1.2.0	dc65570cc6…
```

Maintained by `rpk <pkg> major|minor|patch`, which bumps the latest line
and appends a new one with the current HEAD SHA.

`rpk <pkg> commit <version>` returns the SHA for a version by reading
this file. Versions without a SHA cannot be packaged (there is no commit
to check out).

### `.rpk/package`

Executable, invoked by `rpk <pkg> package [version]` (and implicitly by
`install` and `update`).

**Contract:**
- cwd is the package's git worktree
- `$1` is the target version (may be empty — then use the latest from the
  ledger)
- exit 100 via `die` on any unrecoverable error
- must leave the worktree on the original branch after returning
- on success, must produce a file tree under
  `$(rpk bundle $(rpk type))/<package>-<version>/` that looks like an
  install prefix

**Standard skeleton:**

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
trap "git checkout $BRANCH --force" EXIT

git config advice.detachedHead false
git checkout "$COMMIT" || die "failed to checkout $COMMIT"

# --- build-system-specific commands go here ---
./configure --prefix="$TARGET"
make
make install
# ---------------------------------------------

git checkout "$BRANCH" --force
```

The script assumes `rpk` is reachable on `$PATH`. When `rpk <pkg> package`
invokes `.rpk/package`, it runs as a subprocess of rpk itself, so the
invoking `rpk` is already on `$PATH`.

Only the block between the comment markers changes from one package to
another. See the cookbook below.

### `.rpk/install`

Optional. Runs after `stow` has linked the bundle into the target. cwd is
the package worktree. `$1` is the installed version. Use for registering
systemd units, seeding config files, post-install migrations, etc. Exit
non-zero on failure.

### `.rpk/delete`

Optional. Runs during `rpk <pkg> delete` after stow unlinks the bundle.

### `.rpk/depends/*`

A directory of executable scripts, one per prerequisite. `rpk <pkg>
depends` runs each in turn.

Convention: detect the platform's package manager and install the missing
binary. Stop silently if the binary is already present.

```bash
#!/bin/bash

if [ -x /opt/local/bin/port ]; then
	which make > /dev/null || rpk action sudo port install make
elif [ -x /usr/bin/apt-get ]; then
	which make > /dev/null || rpk action sudo apt-get --yes install make
elif [ -x /usr/local/bin/brew ] || [ -x /opt/homebrew/bin/brew ]; then
	which make > /dev/null || rpk action brew install make
elif [ -x /usr/bin/dnf ]; then
	which make > /dev/null || rpk action sudo dnf install -y make
elif [ -x /usr/bin/pacman ]; then
	which make > /dev/null || rpk action sudo pacman -S --noconfirm make
fi
```

Name the script after the binary it provides (`depends/make`,
`depends/git`, `depends/openssl`). Keep them minimal — one prereq each.

### `.rpk/identity`

Optional single-line file containing the package name. If absent, the
package name is the repository's directory basename (with a leading
`rpk-` stripped, if present). Use this when the repository and package
names must differ.

## The install pipeline

`rpk <pkg> install [version]`:

1. Resolve target version (default: latest from `.rpk/versions`).
2. If the bundle for this version doesn't exist yet, invoke `.rpk/package`.
3. For every previously installed bundle of this package, run
   `stow --delete`.
4. `stow` the new bundle into `$(rpk target <type>)`.
5. Record the installed version at `$XDG_DATA_HOME/rpk/<package>`.
6. If `.rpk/install` exists, execute it.

Implication: the layout your `.rpk/package` writes under the bundle dir
is the layout the user sees after install (as symlinks).

## Build-system cookbook

Minimal `.rpk/package` bodies — replace only the build commands in the
standard skeleton. `$TARGET` is the bundle directory.

### Autoconf / Make

```
./configure --prefix="$TARGET"
make
make install
```

### CMake

```
mkdir -p build
cmake -B build -S . -DCMAKE_INSTALL_PREFIX="$TARGET"
cmake --build build
cmake --install build
```

### Cargo (Rust)

```
cargo install --root "$TARGET" --path .
```

### Go

```
mkdir -p "$TARGET/bin"
GOBIN="$TARGET/bin" go install ./...
```

### npm (global install)

```
mkdir -p "$TARGET"
npm install --prefix="$TARGET" --global .
```

### Python (pip + pyproject)

```
python -m pip install --prefix="$TARGET" .
```

### Pure scripts / assets

```
mkdir -p "$TARGET/bin" "$TARGET/share/<pkg>"
install -m 0755 bin/* "$TARGET/bin/"
cp -a share/ "$TARGET/share/<pkg>/"
```

### Wrapper around a system package

For packages that wrap an apt/port/brew install rather than building from
source, `.rpk/package` can be a no-op (`exit 0`) and everything lives in
`.rpk/depends/*`. `rpk install` will still run depends; skip the packaging
step by omitting `.rpk/package` or making it a no-op.

## Authoring a package from an upstream repository — agent playbook

The task: starting from a GitHub clone of an arbitrary project, produce a
`.rpk/` directory that makes it installable via rpk.

1. **Clone** the upstream repository and enter it.
2. **Detect the build system.** Look for, in order:
   - `configure.ac` / `configure` → autoconf
   - `CMakeLists.txt` → CMake
   - `Cargo.toml` → Cargo
   - `go.mod` → Go
   - `package.json` → npm
   - `pyproject.toml` / `setup.py` → pip
   - `Makefile` alone → plain make; inspect it for a `PREFIX` or `DESTDIR`
     variable
   - `bin/` with no build files → pure-scripts package
3. **Identify the prefix interface.** Confirm the chosen build system
   accepts a custom install prefix. If not (rare), a wrapper script under
   `$TARGET/bin/` that invokes the upstream binary from its native
   location is acceptable.
4. **Enumerate OS dependencies.** From the build system's docs or the
   project's README, list every binary/library the build needs (compiler,
   linker, `pkg-config`, libssl, …). Each becomes a `.rpk/depends/<name>`
   script using the pattern above.
5. **Pick a package name** — usually the repository's directory basename.
   If the repo is named `rpk-<foo>`, the package name is `<foo>`; rpk
   strips the prefix automatically. Override with `.rpk/identity` if
   needed.
6. **Decide `type`.** If the package installs user-facing binaries and
   doesn't require root, use `user`. If it installs system services or
   needs root-writable directories, use `system`.
7. **Seed `.rpk/versions`.** Pick a subset of upstream versions to
   publish. Sources, in order of preference:
   - Signed/annotated git tags (e.g. `v1.2.3`, `1.2.3`)
   - Release entries in `CHANGELOG.md` or GitHub Releases
   - Version fields in `package.json` / `Cargo.toml` / `pyproject.toml`
     combined with commits on `main`
   For each version, resolve its commit SHA
   (`git rev-parse <tag>^{commit}`) and append
   `<semver>\t<commit-sha>` to `.rpk/versions`. Order earliest first. If
   the upstream uses `v` prefixes, strip them.
8. **Write `.rpk/package`** using the standard skeleton plus the
   appropriate cookbook recipe for the detected build system.
9. **Write `.rpk/depends/*`** — one script per OS dependency.
10. **Smoke-test without installing:**
    ```
    rpk init                              # creates local bare repo
    rpk <pkg> package <latest-version>    # should produce a bundle
    ls $(rpk bundle $(rpk type))/<pkg>-<latest-version>/
    ```
    The bundle should contain a sensible `bin/`, `share/`, etc.
11. **Install:**
    ```
    rpk <pkg> depends                     # install prereqs
    rpk <pkg> install                     # stow into target
    ```
    Then confirm the installed binary runs from the target path.
12. **Commit** the `.rpk/` directory and push to whichever remote hosts
    the bare repo.

## Bootstrapping a new package

```
cd my-repo
rpk init                       # scaffolds .rpk/ + sets up local bare repo
# edit .rpk/package, .rpk/depends/*, .rpk/type
git add .rpk && git commit -m "rpk packaging"
rpk <pkg> patch                # record a version with current HEAD
rpk <pkg> install              # package + stow into ~/.local
```

## Troubleshooting

- **"no bare repository found"** — `rpk init` hasn't been run in this
  worktree, or the bare at `$XDG_DATA_HOME/repo/<package>` was removed.
  Re-run `rpk init`.
- **"version X has no commit hash"** — the ledger entry for X is missing
  the SHA column. Append `\t<commit-sha>` manually, or delete the entry
  and re-create it via `rpk <pkg> patch`.
- **stow conflicts** — two packages are trying to install the same path.
  Resolve by dropping the conflicting one (`rpk <other> delete`) or by
  renaming files so they don't overlap.
- **"system packages have to be installed as root"** — switch
  `.rpk/type` to `user`, or run as root.
- **Bundle is empty after `rpk <pkg> package`** — the build-system
  commands ran but didn't honour `$TARGET`. Double-check the `--prefix=`
  or equivalent flag is wired to `"$TARGET"`, not to `$HOME/.local`.

## See also

- `rpk(1)` — full CLI reference (installed as a man page).
- The rpk source repository itself for a working example: its `.rpk/`
  directory packages rpk with itself.
