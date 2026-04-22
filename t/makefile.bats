#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

# Re-root INSTALL_PREFIX into the per-test sandbox so `make install` and
# `make clean` can't touch the user's real ~/.local.
prefix() { echo "$SANDBOX/prefix"; }

repo_root() { cd "$BATS_TEST_DIRNAME/.." && pwd; }

@test "make install populates only rpk-scoped paths under INSTALL_PREFIX" {
	make -C "$(repo_root)" install INSTALL_PREFIX="$(prefix)" >/dev/null
	# Expected artefacts
	[ -L "$(prefix)/bin/rpk" ]
	[ -f "$(prefix)/etc/bash_completion.d/rpk" ]
	[ -f "$(prefix)/share/man/man1/rpk.1" ]
	[ -f "$(prefix)/share/doc/rpk/PACKAGING.md" ]
	[ -f "$(prefix)/share/claude/skills/rpk-author/SKILL.md" ]
	[ -f "$(prefix)/share/raven/skills/rpk-author/SKILL.md" ]
	[ -f "$(prefix)/share/opencode/commands/rpk-author.md" ]
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
