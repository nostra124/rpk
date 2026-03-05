# AGENTS.md - Operational Playbook for rpk

This guide trains autonomous agents that work inside the rpk repository.
It focuses on bash-first development, reproducible builds, and clear testing.
Assume GNU userland on macOS; adapt paths carefully when scripting.
## Repository Snapshot
bin/rpk            - primary 1200-line bash entrypoint invoked by end users.
etc/               - bash completion plus config assets rsynced during install.
share/             - shared data consumed by bin/rpk helpers.
t/*.t              - bash test scripts executed with plain bash.
Makefile           - orchestrates lint, test, and install targets.
README.md          - end-user overview and command reference.
No submodules; cloning repo is sufficient for hacking.
No .cursor or Copilot policy files currently exist.
Shell style instructions live in this document; keep it authoritative.
## Build, Lint, and Test Commands
make all           # runs lint (alias check) and full test suite.
make lint          # shellcheck every script in bin/ (skips if absent).
make check         # alias for make lint to match CI expectations.
make test          # runs every t/*.t file via bash, stops on first failure.
bash t/<name>.t    # run a single test directly; keep env minimal.
SELF_DEBUG=1 ...   # prepend to surface verbose execution tracing.
INSTALL_PREFIX=/tmp/rpk make install  # stage artifacts under custom root.
make install-bin   # symlink scripts into INSTALL_BIN (default ~/.local/bin).
make install-etc   # rsync etc/ into INSTALL_ETC (default ~/.local/etc).
make install-share # rsync share/ likewise; invoked by make install.
make clean         # removes installed files in current INSTALL_PREFIX.
## Test Execution Notes
Tests are POSIX-friendly bash files with executable permission assumptions.
Always run from repo root to preserve relative paths.
Use env var overrides (e.g., XDG_CONFIG_HOME) instead of editing tests.
Capture stdout/stderr when debugging by tee-ing output.
Keep tests idempotent; they may be rerun without clean checkout.
Avoid sourcing bin/rpk directly inside tests; invoke the binary.
Prefer temp directories under "/tmp/rpk-test.$$" and clean them.
When adding tests, mirror naming pattern t/<feature>.t.
Document fixtures inline; avoid hidden binary blobs.
## Tooling & Runtime Expectations
Primary shell is /bin/bash; stick to bashisms already present in bin/rpk.
shellcheck must pass locally (SC2004 style warnings are acceptable if intentional).
GNU coreutils, git, and rsync are assumed available.
Avoid macOS-specific flags when portable alternatives exist.
Use git for repository state inspection; do not rely on external wrappers.
No CI config is present, so local diligence is the enforcement mechanism.
Make targets run sequentially; parallel invocations are not supported.
Binary dependencies for packages live under .rpk/depends/ per package repo spec.
GNU Stow is referenced indirectly; do not add hard dependency unless necessary.
## Shell Coding Standards
Every script starts with "#!/bin/bash" followed immediately by debug guard.
[ -n "$SELF_DEBUG" ] && set -vx to match existing tracing contract.
Global constants are uppercase (VERSION, SELF_CONFIG).
Local variables must be declared with "local name" near first use.
Functions are snake_case or command:subcommand when routing CLI verbs.
Quote every variable expansion unless deliberately globbing.
Use [[ ... ]] for tests, not [ ... ], to avoid glob surprises.
Prefer $(command) subshells instead of backticks.
Default variables with ": ${VAR:=default}" to satisfy shellcheck.
Arrays are rarely used; when needed, declare with () and quote expansions.
Imports happen via source statements inside bin/rpk; keep relative paths explicit.
## Command and Function Architecture
bin/rpk is organized as utility helpers, option parsing, and dispatchers.
Utility helpers include fatal(), die(), debug(), info(), warn(), validate_*().
Command entrypoints follow command:name() naming and are invoked via dispatch.
When adding a command, register it in the dispatch case near the file tail.
Keep shared helpers above option parsing so they are defined before use.
Avoid global side effects when sourcing additional files; prefer functions.
Use has() helper to detect functions of the form kind:name before calling.
Respect existing stage/install workflow semantics to prevent data loss.
## Error Handling & Logging
fatal "message" exits 1 with red text; use for unrecoverable states.
die "message" exits 100 for package/install scripts consumed by rpk.
warn/info helpers colorize output; ensure they obey SELF_QUIET/SELF_VERBOSE.
debug() only prints when SELF_DEBUG is set; retain lightweight string building.
Validate user input (package or account names) with validate_* helpers.
Return non-zero exit status immediately after printing fatal/warn context.
When calling external commands, guard with "command -v" checks.
Document non-obvious failure modes inline with short comments.
Propagate stderr from subshells to help end users diagnose issues.
## Option Parsing & Environment
Use getopts for short flags; stick to "qdf" currently defined.
After getopts, shift $((OPTIND-1)) exactly once.
Support SELF_FORCE, SELF_DEBUG, SELF_QUIET, SELF_VERBOSE semantics.
Honor XDG base directories: CONFIG, CACHE, DATA with provided defaults.
Paths derived from HOME must be overridable via env vars.
When manipulating directories, ensure they exist with mkdir -p before use.
Prefer "cd" wrapped inside subshells to avoid leaking directory changes.
Trap cleanup with "trap '...' EXIT" when temporary state must be reverted.
When touching git worktrees, confirm directories contain .git unless intentionally removed.
## Output & Color Policy
Colors rely on ESC sequences; keep the exact sequences already in helper functions.
Printing should centralize through info/debug/fatal to stay consistent.
Do not introduce new color schemes unless absolutely necessary.
Respect quiet mode by bypassing info output when SELF_QUIET is set.
Verbose mode can reuse info() but should not duplicate debug streams.
When logging multiline messages, prefix each line with "$SELF -" for clarity.
## Filesystem Discipline
All packaging content lives under ~/.local by default for non-root users.
Use rsync -a --exclude='.*' when copying tree content (see Makefile).
Symlinks are created with ln -sf to allow idempotent installs.
Before creating directories, validate parent location to avoid / unintended writes.
Temporary directories should be under ${TMPDIR:-/tmp} with predictable prefixes.
When cleaning, never rm -rf arbitrary user paths; scope to INSTALL_PREFIX.
Use test -f or -d before assuming resources exist.
## Package & Installation Workflow
rpk treats each git repo as a package; metadata lives in .rpk/ subdir.
depends/ scripts check and install prerequisites (ports, apt-get, etc.).
package script builds bundle under rpk bundle paths, often using rsync.
install script applies bundle into target tree (user/system).
versions file enumerates available releases; version command reads it.
stage command clones worktrees under SELF_SOURCES; ensure git refs are clean.
sync/pull/push commands rely on SSH; respect existing key expectations.
bundle directories differentiate home/system contexts; never mix them.
cleanup command prunes stale bundles; be cautious deleting user data.
SemVer is implied (major/minor/patch); keep release logic compatible.
## Git Workflow Expectations
Assume contributors work on topic branches; no automated hooks defined.
Keep commits focused; avoid bundling unrelated formatting changes.
Never rewrite history on shared branches without explicit user request.
Respect untracked changes left by the user; do not delete or reset them.
Use git status/diff frequently before staging or committing.
When scripting git interactions, capture failure codes and report clearly.
Tests may rely on git configuration (user.name); mock where necessary.
Do not add submodules unless absolutely justified.
## External Policy Files
There are currently no Cursor rules (.cursor/rules/ or .cursorrules).
There are currently no Copilot rules (.github/copilot-instructions.md).
This AGENTS.md acts as the single source of meta guidance for agents.
## Agent Decision Checklist
1. Read Makefile for supported targets before inventing new workflows.
2. Use provided Make targets or direct bash invocations; avoid npm/python guesses.
3. When editing scripts, mirror existing helper patterns and naming.
4. Keep new functions shellcheck-clean; run make lint proactively.
5. Add or update tests in t/ when behavior changes; mention single-test command.
6. Validate package/account names via helpers before touching the filesystem.
7. Prefer info/debug/fatal wrappers over raw echo for user messaging.
8. Respect INSTALL_PREFIX and XDG overrides in every file operation.
9. Keep changes ASCII unless the touched file already uses Unicode.
10. Summarize your work clearly and never revert user changes.
11. After edits, suggest running make lint and make test (or targeted files).
12. When uncertain about destructive operations, ask a targeted question once.
13. Avoid introducing new external dependencies without documenting them here.
14. Ensure AGENTS.md stays around 150 lines; update this doc when norms evolve.
15. Remember bin/rpk is the contract; align behavior and tests with it.
## Quick Command Recap
run-lint: make lint
run-test: make test
run-one-test: bash t/<test>.t
run-build: make all
run-install: make install INSTALL_PREFIX=$HOME/.local
Future agents should treat this block as canonical quick reference.
