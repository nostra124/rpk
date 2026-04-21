---
name: rpk-author
description: Create or update the .rpk/ directory of a git repository so it can be versioned, packaged, and installed with rpk.
---

Turn the current git repository into an rpk package by scaffolding its
`.rpk/` directory.

Read the packaging guide before acting:
- `~/.local/share/doc/rpk/PACKAGING.md` (user install)
- `/usr/local/share/doc/rpk/PACKAGING.md` (system install)

CLI reference: `man rpk`.

## Steps

1. **Detect** the project's build system. Look for `configure.ac`,
   `CMakeLists.txt`, `Cargo.toml`, `go.mod`, `package.json`,
   `pyproject.toml`, a Makefile with `PREFIX`, or a pure `bin/`
   directory.
2. **Seed versions.** From `git tag -l` or the project's explicit version
   file, pick the versions to publish. Resolve each to its commit SHA via
   `git rev-parse <ref>^{commit}`. Write them to `.rpk/versions` as
   `<semver><TAB><commit-sha>`, earliest first.
3. **Scaffold** the rest of `.rpk/`:
   - `.rpk/type` — `user` or `system`
   - `.rpk/package` — use the cookbook recipe in PACKAGING.md that matches
     the detected build system
   - `.rpk/depends/<bin>` — one script per OS prerequisite, using the
     per-platform detection pattern (MacPorts, apt, brew, dnf, pacman)
4. **Smoke-test**:

       rpk init
       rpk <pkg> depends
       rpk <pkg> package <latest-version>
       rpk <pkg> install

5. **Report** what you scaffolded. Ask before committing `.rpk/` and
   before pushing.

## Guardrails

- Every `.rpk/versions` SHA must be resolved against the actual
  repository. Do not invent SHAs.
- Verify the build system accepts a custom install prefix before writing
  `.rpk/package`. If it does not, stop and tell the user.
- For OS dependencies, only write `depends/*` scripts for prereqs the
  build system actually needs. Do not guess.
- Do not run `git add` / `git commit` / `git push` without explicit
  confirmation.
