---
name: rpk-author
description: Turn a git repository into an rpk package by scaffolding the .rpk/ directory. Trigger when the user wants to package a project for rpk, convert a GitHub clone into an rpk package, "make this an rpk package", or add/edit the .rpk/ folder of a repo. Also trigger when the user is inspecting an unfamiliar .rpk/ directory and wants guidance.
---

# rpk-author

Create or update the `.rpk/` directory in a git repository so it can be
versioned, built, and installed by the `rpk` package manager.

## When to use

- "Make this an rpk package"
- "Add rpk packaging to this repo"
- "Package <github-repo> for rpk"
- "Set up `.rpk/` for this project"
- "Publish this to my rpk bare repos"

## Guardrails

- **Read PACKAGING.md first.** Do not act from memory. Locate it:
  - `~/.local/share/doc/rpk/PACKAGING.md` (user install)
  - `/usr/local/share/doc/rpk/PACKAGING.md` (system install)
  - `docs/PACKAGING.md` in the rpk source repository
- **Don't invent commit SHAs.** Every entry in `.rpk/versions` must come
  from `git rev-parse <ref>^{commit}` run against the actual repository.
- **Don't invent install prefixes.** If the build system doesn't accept a
  custom prefix, stop and report — do not fake `$TARGET` by hand-copying
  files unless the user explicitly asks for that fallback.
- **Don't commit without confirmation.** Scaffold, verify, then ask.

## Workflow

1. **Read** `PACKAGING.md` end-to-end (especially the "Authoring a
   package from an upstream repository — agent playbook" section).
2. **Identify** the project's build system (`configure.ac`,
   `CMakeLists.txt`, `Cargo.toml`, `go.mod`, `package.json`,
   `pyproject.toml`, Makefile with `PREFIX`, or pure scripts).
3. **Seed versions** from `git tag -l` or the project's explicit version
   files. Resolve each to a commit SHA.
4. **Scaffold** `.rpk/type`, `.rpk/versions`, `.rpk/package` (using the
   cookbook recipe matching the build system), and `.rpk/depends/*` for
   OS prerequisites.
5. **Smoke-test** locally:
   ```
   rpk init
   rpk <pkg> depends
   rpk <pkg> package <latest-version>
   rpk <pkg> install
   ```
6. **Report** what you scaffolded and what to verify before committing.
   Ask before `git add` / `git commit` / `git push`.

## Common failure modes

- "version X has no commit hash" — the ledger line is missing its tab +
  SHA column.
- Empty bundle after `rpk <pkg> package` — the build didn't honour
  `$TARGET`; check the prefix flag wiring.
- Stow conflict on install — another installed package claims the same
  path. Uninstall the conflicting one or rename.

## CLI reference

`man rpk` for the full command surface.
