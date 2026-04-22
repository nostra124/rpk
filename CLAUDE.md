# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

`rpk` is a bash-only package manager. Each "package" is a git repo containing an `.rpk/` directory with a `package` script (to build a versioned bundle) and optionally `install`, `depends/`, `versions`, `type`. Bundles are laid down into `$HOME/.local` (user) or `/usr/local` (system) via GNU Stow symlinks.

This repo is **self-hosted**: rpk is itself an rpk package (see `.rpk/` at the repo root).

Also read `AGENTS.md` — it is the authoritative shell-style and operational guide and is kept current. The notes below cover what isn't obvious from reading the code.

## Commands

```bash
./configure --prefix=$HOME/.local   # generates config.mk (autoconf-style wrapper over the Makefile)
make all                            # = make check test
make lint                           # shellcheck bin/* (silently skips if shellcheck absent)
make check                          # alias for make lint
make test                           # runs every t/*.t via bash; currently no t/ dir exists, so no-op
make install                        # install-bin + install-etc + install-share (symlinks bin/, rsyncs etc/ and share/)
INSTALL_PREFIX=/tmp/rpk make install   # stage into an alternate root
```

Single test: `bash t/<name>.t` (no tests committed yet; add under `t/<feature>.t` to run through `make test`).

Debug tracing: prefix any invocation with `SELF_DEBUG=1` — the `[ -n "$SELF_DEBUG" ] && set -vx` guard on line 8 of `bin/rpk` turns on `set -vx` before anything else runs. The same guard convention applies to `.rpk/package` and similar scripts.

## Architecture

**One file does almost everything.** `bin/rpk` is a ~1350-line bash monolith, structured top-to-bottom as:

1. **Logging/validation helpers** — `fatal` (exits 1, red), `warn`, `info`, `debug`, `validate_package_name`, `validate_account_name`, `has <kind> <name>` (checks whether a function `kind:name` exists).
2. **Early getopts pass** (line ~66) for `-q -d -f -v` → `SELF_QUIET`, `SELF_DEBUG`, `SELF_FORCE`, `SELF_VERBOSE`. This runs *before* command dispatch so flags affect everything.
3. **XDG path resolution** — derives `SELF_CONFIG`, `SELF_CACHE`, `SELF_DATA`, `SELF_SOURCES` (`~/.local/src`), `SELF_REPO` (`$XDG_DATA_HOME/repo`, holds bare git repos). Respect these env vars in any new code.
4. **Internal helpers** named `rpk:*` (e.g. `rpk:bare`, `rpk:ssh-known-accounts`) and `push:branches`.
5. **CLI verbs** named `command:<verb>` (~45 of them: `stage`, `install`, `package`, `update`, `sync`, `pull`, `push`, `release`, `major/minor/patch`, `changelog`, `init`, `bundles`, `cleanup`, `list`, `show`, `type`, `target`, `bundle`, `worktree`, `identity`, …). Each new CLI verb is a new `command:<name>` function — there is no explicit registration; the dispatch footer uses `has command <name>` to find it.
6. **Per-command help** as `help:<verb>` functions, consumed by `command:help`.
7. **Dispatch footer** (line ~1308). This is the part worth understanding before adding features:
   - If `$1` matches a known package name (`command:list`), it is stripped off and `$PACKAGE`/`$WORKTREE` are set from `$SELF_SOURCES/<pkg>` or `$SELF_SOURCES/rpk-<pkg>`.
   - Otherwise, if cwd is inside a git worktree, `$PACKAGE` is read from `.rpk/identity` (or derived from the repo basename, stripping a leading `rpk-`).
   - Then: if `$1` is a known `command:*`, it is called. Otherwise, if `$PACKAGE` is set and `$WORKTREE/command/<verb>` is executable, that package-local script is invoked (this is how packages extend rpk with their own subcommands). Otherwise, fatal.

**Package-script exit code contract.** `fatal` (host-side) exits 1. `die` in `.rpk/package` / `.rpk/install` exits **100** — the install/package pipeline distinguishes host failures from user-script failures by this code. Keep new package-script helpers on exit 100.

**Version/release model.** `.rpk/versions` is an append-only tab-separated ledger: `<semver>\t<commit-sha>`. `command:major|minor|patch` bump the last entry, append, commit, and push to the `local` remote (a bare repo at `$SELF_REPO/<package>`). `command:changelog` diffs `git log PREV..CURR` using the commits recorded in that file. The literal `VERSION='1.0.0'` near the top of `bin/rpk` is stale and not authoritative — `command:version` reads `.rpk/versions` / `$SELF_DATA/<pkg>` instead.

**Install flow.** `command:install` → ensures a bundle exists at `$(command:bundle <type>)/<pkg>-<version>` (calling `command:package` if missing, which runs `.rpk/package <version>` — typically `./configure --prefix=<bundle> && make && make install` on a detached tag checkout) → `stow --delete` any previously stowed versions of that package → `stow` the new one into `$(command:target <type>)` (`~/.local` or `/usr/local`). Records the installed version in `$SELF_DATA/<pkg>`.

**Remote sync model.** Every non-local remote is an SSH destination (`user@host`). Bare repos live at `~/.local/var/lib/repo/<pkg>` on the remote. `pull`/`push`/`sync`/`release` all assume SSH key auth works for the account. `release` additionally `scp`s the current `rpk` script to `/tmp/rpk` on the remote and runs `update` there.

## Conventions worth preserving

- New CLI verbs: define `command:<verb>()`, match the existing `[ -n "$PACKAGE" ] && validate_package_name "$PACKAGE"` guard pattern where the verb operates on a package, and add a matching `help:<verb>()` if it takes arguments.
- Prefer `info`/`warn`/`debug`/`fatal` over raw `echo` so `-q`/`-v`/`-d` behave consistently and colors stay uniform.
- Keep helpers above their first caller; `bin/rpk` is read top-to-bottom and relies on that ordering.
- Bundle dirs (`~/.local/pkg` vs `/usr/local/pkg`) and target dirs (`~/.local` vs `/usr/local`) must not be mixed — `command:bundle` and `command:target` enforce `home`/`user`/`system` and refuse system without root.
