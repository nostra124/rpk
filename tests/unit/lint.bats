#!/usr/bin/env bats

load helpers

@test "shellcheck passes at severity=warning on bin/rpk" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck not installed"
	fi
	run shellcheck --severity=warning "$RPK_BIN"
	[ "$status" -eq 0 ]
}

@test "shellcheck passes on .rpk/* scripts (FEAT-003)" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck not installed"
	fi
	local repo_root
	repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	run shellcheck --severity=warning \
		"$repo_root/.rpk/package" \
		"$repo_root"/.rpk/depends/*
	[ "$status" -eq 0 ]
}

@test "rpk script is valid bash syntax" {
	run bash -n "$RPK_BIN"
	[ "$status" -eq 0 ]
}

@test "no stale top-level VERSION= constant (BUG-003 regression)" {
	# The original bug was a hardcoded `VERSION='1.0.0'` near the top of the
	# script. Look for `^VERSION=` in the first 50 lines only — beyond that
	# we're inside function bodies or heredoc templates (e.g. init scaffolds
	# a `.rpk/package` that legitimately uses `VERSION=$1`).
	run bash -c "head -50 '$RPK_BIN' | grep -nE '^VERSION='"
	[ "$status" -eq 1 ]
}
