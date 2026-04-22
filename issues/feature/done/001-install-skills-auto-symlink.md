---
id: FEAT-001
type: feature
priority: medium
status: done
---

# Auto-symlink installed agent skills into user config dirs

## Description

**As a** user installing rpk
**I want** `make install` to also activate the bundled agent skills in
the configuration directories each agent reads from
**So that** Claude Code, opencode, and raven pick up `rpk-author`
immediately, without me having to remember the exact `ln -s` incantation
that today's `install-skills` target prints at the end.

## Implementation

Add a `make install-skills-user` target that, for each supported agent,
creates a symlink *if and only if* the user-side config dir already
exists (so it's an opt-in activation that doesn't create dotfile dirs
behind the user's back):

- `$HOME/.claude/skills/rpk-author` →
  `$(INSTALL_SHARE)/claude/skills/rpk-author`
- `$HOME/.raven/workspace/skills/rpk-author` →
  `$(INSTALL_SHARE)/raven/skills/rpk-author`
- `$HOME/.config/opencode/commands/rpk-author.md` →
  `$(INSTALL_SHARE)/opencode/commands/rpk-author.md`

`make install` stays at its current behaviour (install files, print
hints). `install-skills-user` is a separate opt-in target.

Corresponding `uninstall-skills-user` target that removes only the
symlinks this target creates.

## Acceptance Criteria

1. `make install-skills-user` symlinks the three artefacts if the
   matching user dir exists, otherwise skips that agent with a clear
   message.
2. Never creates `~/.claude`, `~/.raven/workspace`, or
   `~/.config/opencode` on behalf of the user.
3. Idempotent: running twice is safe.
4. `make uninstall-skills-user` removes only the symlinks it would
   have created.
5. Documented in `docs/PACKAGING.md` under a "Agent integration"
   section.
