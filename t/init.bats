#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

@test "init in a fresh git repo creates .rpk/ skeleton" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"

	run rpk init
	[ "$status" -eq 0 ]

	[ -d "$repo/.rpk" ]
	[ -d "$repo/.rpk/depends" ]
	[ -f "$repo/.rpk/type" ]
	[ -f "$repo/.rpk/versions" ]
	[ -x "$repo/.rpk/package" ]
}

@test "init scaffolds AGENTS.md at the repo root" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	run rpk init
	[ "$status" -eq 0 ]
	[ -f "$repo/AGENTS.md" ]
}

@test "init writes type=user by default" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	run cat "$repo/.rpk/type"
	[ "$output" = "user" ]
}

@test "init seeds versions with 0.0.1" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	run cat "$repo/.rpk/versions"
	[[ "$output" == *"0.0.1"* ]]
}

@test "init adds a 'local' git remote pointing at the bare repo path" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	run git -C "$repo" remote get-url local
	[ "$status" -eq 0 ]
	[[ "$output" == *"/repo/myproject"* ]]
}

@test "init is idempotent — preserves edits to scaffolded files" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	echo "system" > "$repo/.rpk/type"
	rpk init
	run cat "$repo/.rpk/type"
	[ "$output" = "system" ]
}

@test "scaffolded .rpk/package uses commit SHAs, not tag refs" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	run cat "$repo/.rpk/package"
	[[ "$output" != *"refs/tags"* ]]
	[[ "$output" == *"commit"* ]]
}

@test "AGENTS.md scaffold references PACKAGING.md" {
	local repo
	repo=$(make_repo "myproject")
	cd "$repo"
	rpk init
	run cat "$repo/AGENTS.md"
	[ "$status" -eq 0 ]
	[[ "$output" == *"PACKAGING.md"* ]]
	[[ "$output" == *"rpk"* ]]
}

@test "init in a non-git directory fatals" {
	mkdir -p "$HOME/not-a-repo"
	cd "$HOME/not-a-repo"
	run rpk init
	[ "$status" -ne 0 ]
}
