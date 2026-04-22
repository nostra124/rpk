---
id: BUG-002
type: bug
priority: medium
status: open
---

# BUG-002: `make clean` wipes every package's share dir, not just rpk's

## Severity
Medium — data loss for every *other* rpk-installed package on a
multi-package install. No destructive intent from the user triggers it;
they just ran `make clean` in the rpk source.

## Observed
Current `Makefile` target:

    clean:
    	@echo "Cleaning up..."
    	@rm -rf $(INSTALL_PREFIX)/bin/rpk $(INSTALL_PREFIX)/etc/scripts $(INSTALL_PREFIX)/share/*

`$(INSTALL_PREFIX)/share/*` matches every file and directory under
`~/.local/share`, not just rpk's own payload. Running `make clean`
therefore removes other packages' installed `share/` trees,
`share/man/` for everything else, and any user data that happens to
live under the prefix's share dir.

Separately: `$(INSTALL_PREFIX)/etc/scripts` was never an install
target (rpk installs to `$(INSTALL_PREFIX)/etc/bash_completion.d/`),
so that path is also wrong.

## Root Cause
`clean` was written as `rm -rf` over best-effort paths without
reference to what `install-*` actually produced.

## Fix plan
Rewrite `clean` to undo exactly what `install` created:

1. Remove the symlink at `$(INSTALL_BIN)/rpk` (but not other scripts
   already in `INSTALL_BIN`).
2. Remove `$(INSTALL_ETC)/bash_completion.d/rpk`.
3. Remove `$(INSTALL_MAN)/man1/rpk.1` and any other rpk-owned pages.
4. Remove `$(INSTALL_DOC)` (the whole `share/doc/rpk/` dir — it's
   rpk-scoped).
5. Remove the installed skill trees:
   `$(INSTALL_SHARE)/claude/skills/rpk-author/`,
   `$(INSTALL_SHARE)/raven/skills/rpk-author/`,
   `$(INSTALL_SHARE)/opencode/commands/rpk-author.md`.

Use `rm -rf -- "$path"` with explicit per-artefact paths, never a glob
against a shared directory.

## Regression Protection
Add a bats test that runs `make install INSTALL_PREFIX=<sandbox>`,
plants a decoy file under `<sandbox>/share/other-package/`, runs
`make clean INSTALL_PREFIX=<sandbox>`, and asserts the decoy survives.
