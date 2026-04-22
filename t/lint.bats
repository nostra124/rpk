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
