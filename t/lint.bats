#!/usr/bin/env bats

load helpers

@test "shellcheck passes at severity=warning on bin/rpk" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck not installed"
	fi
	run shellcheck --severity=warning "$RPK_BIN"
	[ "$status" -eq 0 ]
}

@test "rpk script is valid bash syntax" {
	run bash -n "$RPK_BIN"
	[ "$status" -eq 0 ]
}

@test "no stale top-level VERSION= constant (BUG-003 regression)" {
	# A top-level VERSION='...' at column 0 would mask the ledger-based
	# version source. Function-local `VERSION=$1` etc. start with a tab
	# or spaces and are fine.
	run grep -nE '^VERSION=' "$RPK_BIN"
	[ "$status" -eq 1 ]  # grep exits 1 on "no match", which is what we want
}
