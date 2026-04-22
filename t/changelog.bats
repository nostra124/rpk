#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

@test "changelog for a version with no commit hash fatals" {
	make_package "mypkg" >/dev/null
	# Seeded 0.0.1 has no SHA column — changelog can't resolve it.
	run rpk mypkg changelog 0.0.1
	[ "$status" -ne 0 ]
}

@test "changelog for a freshly patched version prints a header and a body" {
	local repo
	repo=$(make_package "mypkg")
	rpk mypkg patch        # -> 0.0.2 with HEAD SHA
	run rpk mypkg changelog 0.0.2
	[ "$status" -eq 0 ]
	# GNU-style header: ISO date, committer name, email in angle brackets
	[[ "$output" == *"Test User"* ]]
	[[ "$output" == *"<test@example.com>"* ]]
	# Section marker references the target version, not the static 1.0.0 global
	[[ "$output" == *"* 0.0.2:"* ]]
}

@test "changelog between two patches lists the intervening commit subjects" {
	local repo
	repo=$(make_package "mypkg")
	rpk mypkg patch                           # -> 0.0.2 (commit "A" = repo's initial HEAD)
	(
		cd "$repo"
		echo "two" > TWO.md
		git add TWO.md
		git commit -q -m "add TWO"
	) >/dev/null
	rpk mypkg patch                           # -> 0.0.3 (commit "A+add TWO")

	run rpk mypkg changelog 0.0.3
	[ "$status" -eq 0 ]
	[[ "$output" == *"add TWO"* ]]
	# the prior-version-bump commit is between the two SHAs → should appear too
	[[ "$output" == *"updated version to 0.0.2"* ]]
}

@test "changelog with no argument uses the latest version" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch                           # 0.0.2
	rpk mypkg patch                           # 0.0.3
	run rpk mypkg changelog
	[ "$status" -eq 0 ]
	[[ "$output" == *"* 0.0.3:"* ]]
}

@test "changelog content is indented (5 spaces per line)" {
	make_package "mypkg" >/dev/null
	rpk mypkg patch
	run rpk mypkg changelog 0.0.2
	[ "$status" -eq 0 ]
	# at least one line in the body starts with five spaces
	[[ "$output" == *$'\n     '* ]]
}
