# Shared helpers for bats tests.

# Absolute path to the rpk under test.
: "${RPK_BIN:=${BATS_TEST_DIRNAME}/../bin/rpk}"

# Create a fresh sandbox $HOME for the current test and reset the env rpk reads.
# All state (XDG dirs, bare repos, staged worktrees) lives inside $SANDBOX
# and is torn down afterwards — tests never touch the user's real dotfiles.
sandbox_setup() {
	SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/rpk-bats.XXXXXX")
	export SANDBOX
	export HOME="$SANDBOX/home"
	mkdir -p "$HOME"

	# Clear XDG overrides so rpk falls back to its $HOME-rooted defaults.
	unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME

	# Clear SELF_* so tests start with default rpk behaviour.
	unset SELF_DEBUG SELF_VERBOSE SELF_QUIET SELF_FORCE

	# Put the rpk under test first on PATH so tests can invoke plain "rpk".
	export PATH="$(dirname "$RPK_BIN"):$PATH"

	# Deterministic git identity for commits the tests make.
	export GIT_AUTHOR_NAME="Test User"
	export GIT_AUTHOR_EMAIL="test@example.com"
	export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
	export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
}

sandbox_teardown() {
	[ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
}

# make_repo <name> — create an initial git worktree under $HOME/<name>, with
# one commit on the default branch, and echo its absolute path.
make_repo() {
	local name=${1:-testpkg}
	local repo="$HOME/$name"
	mkdir -p "$repo"
	(
		cd "$repo"
		git init -q -b main
		echo "hello" > README.md
		git add README.md
		git commit -q -m "initial"
	) >/dev/null
	echo "$repo"
}
