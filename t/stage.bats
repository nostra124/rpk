#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; cd "$HOME"; }
teardown() { sandbox_teardown; }

@test "stage with no package fatals" {
	run rpk stage
	[ "$status" -ne 0 ]
	[[ "$output" == *"no package provided"* ]]
}

@test "stage with no bare repo fatals" {
	# Dispatcher won't even resolve mypkg (not in command:list), so this
	# falls through to "unknown package" / "unknown command" territory.
	run rpk mypkg stage
	[ "$status" -ne 0 ]
}

@test "stage clones a bare repo into the sources tree" {
	setup_bare "mypkg" >/dev/null
	[ ! -d "$HOME/.local/src/mypkg" ]

	run rpk mypkg stage
	[ "$status" -eq 0 ]

	[ -d "$HOME/.local/src/mypkg/.git" ]
	[ -f "$HOME/.local/src/mypkg/README.md" ]
}

@test "stage sets the 'local' remote to the bare repo" {
	local bare
	bare=$(setup_bare "mypkg")

	rpk mypkg stage
	run git -C "$HOME/.local/src/mypkg" remote get-url local
	[ "$status" -eq 0 ]
	[ "$output" = "$bare" ]
}

@test "stage on an existing worktree pulls new commits from the bare" {
	local bare
	bare=$(setup_bare "mypkg")
	rpk mypkg stage

	# Push a second commit through a throwaway clone of the bare.
	local side="$SANDBOX/side"
	git clone -q "$bare" "$side"
	(
		cd "$side"
		echo "second" > NEW.md
		git add NEW.md
		git commit -q -m "second"
		git push -q origin main
	) >/dev/null

	run rpk mypkg stage
	[ "$status" -eq 0 ]
	[ -f "$HOME/.local/src/mypkg/NEW.md" ]
}

@test "stage works for an rpk- prefixed bare repo" {
	setup_bare "rpk-tool" >/dev/null
	# Package name visible to rpk is "tool" (prefix stripped by command:list).
	run rpk tool stage
	[ "$status" -eq 0 ]
	[ -d "$HOME/.local/src/rpk-tool/.git" ]
}
