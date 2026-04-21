#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; cd "$HOME"; }
teardown() { sandbox_teardown; }

@test "no args prints usage and exits 0" {
	run rpk
	[ "$status" -eq 0 ]
	[[ "$output" == *"usage:"* ]]
}

@test "help prints usage" {
	run rpk help
	[ "$status" -eq 0 ]
	[[ "$output" == *"usage:"* ]]
}

@test "help <known-command> prints its help" {
	run rpk help install
	[ "$status" -eq 0 ]
	[[ "$output" == *"install"* ]]
}

@test "help <unknown-command> exits 2" {
	run rpk help nosuchcommand
	[ "$status" -eq 2 ]
}

@test "unknown top-level command fatals" {
	run rpk nosuchcommand
	[ "$status" -ne 0 ]
}

@test "list with no packages succeeds" {
	run rpk list
	[ "$status" -eq 0 ]
}

@test "source prints the rpk sources directory" {
	run rpk source
	[ "$status" -eq 0 ]
	[[ "$output" == *"/.local/src"* ]]
}

@test "repo prints the bare-repo directory" {
	run rpk repo
	[ "$status" -eq 0 ]
	[[ "$output" == *"/repo"* ]]
}

@test "target user prints \$HOME/.local" {
	run rpk target user
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.local" ]
}

@test "bundle user prints \$HOME/.local/pkg" {
	run rpk bundle user
	[ "$status" -eq 0 ]
	[ "$output" = "$HOME/.local/pkg" ]
}

@test "target without arg fatals" {
	run rpk target
	[ "$status" -ne 0 ]
}

@test "platform prints something" {
	run rpk platform
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}
