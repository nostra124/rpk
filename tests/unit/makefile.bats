#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

# Re-root INSTALL_PREFIX into the per-test sandbox so `make install` and
# `make clean` can't touch the user's real ~/.local.
prefix() { echo "$SANDBOX/prefix"; }

repo_root() { cd "$BATS_TEST_DIRNAME/../.." && pwd; }

@test "make install populates only rpk-scoped paths under INSTALL_PREFIX" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	# install-bin copies (not symlinks) so the installed tree is self-
	# contained and safe to use as a stow bundle source.
	[ -x "$(prefix)/bin/rpk" ]
	[ ! -L "$(prefix)/bin/rpk" ]
	[ -f "$(prefix)/etc/bash_completion.d/rpk" ]
	[ -f "$(prefix)/share/man/man1/rpk.1" ]
	[ -f "$(prefix)/share/doc/rpk/PACKAGING.md" ]
	[ -f "$(prefix)/share/claude/skills/rpk-author/SKILL.md" ]
	[ -f "$(prefix)/share/raven/skills/rpk-author/SKILL.md" ]
	[ -f "$(prefix)/share/opencode/commands/rpk-author.md" ]
}

@test "install-skills-user symlinks into existing user agent dirs (FEAT-001)" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	# Simulate a user with Claude Code and opencode already configured,
	# but no Raven workspace.
	mkdir -p "$HOME/.claude/skills"
	mkdir -p "$HOME/.config/opencode/commands"

	make -C "$(repo_root)" install-skills-user INSTALL_PREFIX="$(prefix)" >/dev/null

	[ -L "$HOME/.claude/skills/rpk-author" ]
	[ -L "$HOME/.config/opencode/commands/rpk-author.md" ]
	# Raven dir doesn't exist — so no symlink, no error.
	[ ! -e "$HOME/.raven/workspace/skills/rpk-author" ]
	[ ! -d "$HOME/.raven" ]   # must not have been created
}

@test "uninstall-skills-user removes only symlinks (FEAT-001)" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	mkdir -p "$HOME/.claude/skills"
	mkdir -p "$HOME/.config/opencode/commands"
	make -C "$(repo_root)" install-skills-user INSTALL_PREFIX="$(prefix)" >/dev/null
	# Plant a real (non-symlink) rpk-author file next to the link's target
	# shape to ensure uninstall doesn't blow it away.
	mkdir -p "$HOME/.claude/skills/rpk-author-local"
	echo "keep" > "$HOME/.claude/skills/rpk-author-local/SKILL.md"

	make -C "$(repo_root)" uninstall-skills-user >/dev/null

	[ ! -e "$HOME/.claude/skills/rpk-author" ]
	[ ! -e "$HOME/.config/opencode/commands/rpk-author.md" ]
	# unrelated local file survives
	[ -f "$HOME/.claude/skills/rpk-author-local/SKILL.md" ]
}

@test "install-skills-user is idempotent (FEAT-001)" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	mkdir -p "$HOME/.claude/skills"
	make -C "$(repo_root)" install-skills-user INSTALL_PREFIX="$(prefix)" >/dev/null
	# Second invocation must not fail or change the link target.
	local target_before
	target_before=$(readlink "$HOME/.claude/skills/rpk-author")
	make -C "$(repo_root)" install-skills-user INSTALL_PREFIX="$(prefix)" >/dev/null
	local target_after
	target_after=$(readlink "$HOME/.claude/skills/rpk-author")
	[ "$target_before" = "$target_after" ]
}

@test "make clean removes only rpk-owned paths (BUG-002 regression)" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	# Plant decoys belonging to "other packages".
	mkdir -p "$(prefix)/share/other-package"
	echo "mine" > "$(prefix)/share/other-package/data.txt"
	mkdir -p "$(prefix)/share/claude/skills/other-skill"
	echo "mine" > "$(prefix)/share/claude/skills/other-skill/SKILL.md"
	mkdir -p "$(prefix)/bin"
	echo "mine" > "$(prefix)/bin/some-other-tool"
	chmod +x "$(prefix)/bin/some-other-tool"

	make -C "$(repo_root)" clean INSTALL_PREFIX="$(prefix)" >/dev/null

	# Decoys survive
	[ -f "$(prefix)/share/other-package/data.txt" ]
	[ -f "$(prefix)/share/claude/skills/other-skill/SKILL.md" ]
	[ -x "$(prefix)/bin/some-other-tool" ]

	# rpk artefacts are gone
	[ ! -e "$(prefix)/bin/rpk" ]
	[ ! -e "$(prefix)/etc/bash_completion.d/rpk" ]
	[ ! -e "$(prefix)/share/man/man1/rpk.1" ]
	[ ! -d "$(prefix)/share/doc/rpk" ]
	[ ! -d "$(prefix)/share/claude/skills/rpk-author" ]
	[ ! -d "$(prefix)/share/raven/skills/rpk-author" ]
	[ ! -e "$(prefix)/share/opencode/commands/rpk-author.md" ]
}
