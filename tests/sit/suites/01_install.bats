#!/usr/bin/env bats
#
# SIT 01_install: rpk can be built and installed on a fresh Alpine image
# via the standard `configure && make install` flow, and the resulting
# binary runs end-to-end basic commands.

load ../helpers

setup_file() {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	sit_build_image alpine
}

@test "[alpine] rpk help prints usage" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine rpk help
	[ "$status" -eq 0 ]
	[[ "$output" == *"usage:"* ]]
}

@test "[alpine] rpk platform identifies the distro" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine rpk platform
	[ "$status" -eq 0 ]
	[[ "$output" == *"alpine"* ]]
}

@test "[alpine] rpk list works with no packages" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine rpk list
	[ "$status" -eq 0 ]
}

@test "[alpine] rpk man page installed and queryable" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine sh -c '[ -f /usr/local/share/man/man1/rpk.1 ]'
	[ "$status" -eq 0 ]
}

@test "[alpine] PACKAGING.md shipped under share/doc/rpk" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine sh -c '[ -f /usr/local/share/doc/rpk/PACKAGING.md ]'
	[ "$status" -eq 0 ]
}

@test "[alpine] rpk-author skill available under share/claude/skills" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine sh -c '[ -f /usr/local/share/claude/skills/rpk-author/SKILL.md ]'
	[ "$status" -eq 0 ]
}
