#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

@test "versions lists the seeded 0.0.1 after init" {
	make_package "mypkg" >/dev/null
	run rpk mypkg versions
	[ "$status" -eq 0 ]
	[[ "$output" == *"0.0.1"* ]]
}

@test "patch bumps to 0.0.2 and appends to ledger" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch
	run rpk mypkg versions
	[[ "$output" == *"0.0.1"* ]]
	[[ "$output" == *"0.0.2"* ]]
}

@test "patch records the HEAD commit SHA" {
	local repo
	repo=$(make_package "mypkg")
	local before
	before=$(git -C "$repo" rev-parse HEAD)
	rpk mypkg patch
	run rpk mypkg commit 0.0.2
	[ "$output" = "$before" ]
}

@test "minor bumps second component and resets patch" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch           # 0.0.2
	rpk mypkg minor           # 0.1.0
	run rpk mypkg versions
	[[ "$output" == *"0.1.0"* ]]
	# tail should be the newest
	run bash -c "rpk mypkg versions | tail -1"
	[ "$output" = "0.1.0" ]
}

@test "major bumps first component and resets minor/patch" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch           # 0.0.2
	rpk mypkg minor           # 0.1.0
	rpk mypkg major           # 1.0.0
	run bash -c "rpk mypkg versions | tail -1"
	[ "$output" = "1.0.0" ]
}

@test "commit lookup for an unknown version returns empty" {
	make_package "mypkg" >/dev/null
	run rpk mypkg commit 99.99.99
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "commit lookup for the seeded 0.0.1 returns empty (no SHA)" {
	# The seed line has no tab+SHA, so `commit 0.0.1` is not resolvable.
	make_package "mypkg" >/dev/null
	run rpk mypkg commit 0.0.1
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "version bumps create git commits on main" {
	local repo
	repo=$(make_package "mypkg")
	local before_count
	before_count=$(git -C "$repo" rev-list --count HEAD)
	rpk mypkg patch
	rpk mypkg minor
	local after_count
	after_count=$(git -C "$repo" rev-list --count HEAD)
	[ "$((after_count - before_count))" -eq 2 ]
}

@test "rpk's own .rpk/versions has a SHA for every entry (BUG-001 regression)" {
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	# Every non-blank line must have a tab and a 40-char hex SHA in field 2.
	run awk -F '\t' '
		/^[[:space:]]*$/ { next }
		/^[[:space:]]*#/ { next }
		NF < 2 || $2 !~ /^[0-9a-f]{40}$/ { print NR": "$0; bad=1 }
		END { exit bad }
	' "$repo_root/.rpk/versions"
	[ "$status" -eq 0 ]
}

@test "versions output is sorted by semver" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch     # 0.0.2
	rpk mypkg minor     # 0.1.0
	rpk mypkg patch     # 0.1.1
	rpk mypkg major     # 1.0.0
	rpk mypkg patch     # 1.0.1
	run rpk mypkg versions
	local expected="0.0.1
0.0.2
0.1.0
0.1.1
1.0.0
1.0.1"
	[ "$output" = "$expected" ]
}
