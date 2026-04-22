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

# make_package <name> — create a fresh git repo under $HOME/.local/src/<name>
# (so rpk's dispatcher can resolve it by name), run `rpk init`, and echo the
# absolute path.
make_package() {
	local name=${1:-testpkg}
	local repo="$HOME/.local/src/$name"
	mkdir -p "$repo"
	(
		cd "$repo"
		git init -q -b main
		echo "hello" > README.md
		git add README.md
		git commit -q -m "initial"
		rpk init >/dev/null 2>&1
	) >/dev/null
	echo "$repo"
}

# setup_bare <name> — create a bare git repository at $HOME/.local/var/lib/repo/<name>
# (the location rpk's dispatcher expects for package discovery), seed it with one
# initial commit containing a minimal `.rpk/` skeleton so `command:list` picks
# up clones of this bare, and echo the bare repo's absolute path.
setup_bare() {
	local name=${1:-testpkg}
	local bare="$HOME/.local/var/lib/repo/$name"
	mkdir -p "$(dirname "$bare")"
	git init --bare -q -b main "$bare"

	local seed="$SANDBOX/seed-$name"
	git clone -q "$bare" "$seed" 2>/dev/null
	(
		cd "$seed"
		echo "hello" > README.md
		mkdir -p .rpk/depends
		echo "user" > .rpk/type
		echo "0.0.1" > .rpk/versions
		git add .
		git commit -q -m "initial"
		git push -q origin main
	) >/dev/null
	rm -rf "$seed"
	echo "$bare"
}

# make_buildable_package <name> — like make_package, plus scaffolds a minimal
# autoconf-style build (configure + Makefile) that installs a `hello-<name>`
# script into $(PREFIX)/bin. Suitable for lifecycle tests that exercise the
# package / install / delete pipeline.
make_buildable_package() {
	local name=${1:-testpkg}
	local repo="$HOME/.local/src/$name"
	mkdir -p "$repo"

	cat > "$repo/configure" <<'CONFIGURE'
#!/bin/sh
for arg; do
	case "$arg" in
		--prefix=*) echo "PREFIX=${arg#*=}" > config.mk ;;
	esac
done
CONFIGURE
	chmod +x "$repo/configure"

	cat > "$repo/Makefile" <<MAKEFILE
-include config.mk
PREFIX ?= /usr/local

.PHONY: all install

all: ;

install:
	@mkdir -p \$(PREFIX)/bin
	@printf '#!/bin/sh\necho hello from $name\n' > \$(PREFIX)/bin/hello-$name
	@chmod +x \$(PREFIX)/bin/hello-$name
MAKEFILE

	echo "config.mk" > "$repo/.gitignore"

	(
		cd "$repo"
		git init -q -b main
		git add .
		git commit -q -m "initial"
		rpk init >/dev/null 2>&1
	) >/dev/null
	echo "$repo"
}
