#!/usr/bin/env bats
#
# SIT 02_platform: `rpk platform` returns the correct distro id on each
# supported Linux image. Acceptance criterion #1 of FEAT-006.

load ../helpers

setup_file() {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	sit_build_image alpine
	sit_build_image debian
	sit_build_image fedora
	# Arch Linux has no official arm64 image; skip the build on arm64 hosts.
	if [ "$(uname -m)" != "arm64" ] && [ "$(uname -m)" != "aarch64" ]; then
		sit_build_image arch
	fi
}

@test "[alpine] rpk platform == alpine" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run alpine rpk platform
	[ "$status" -eq 0 ]
	[ "$output" = "alpine" ]
}

@test "[debian] rpk platform == debian" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run debian rpk platform
	[ "$status" -eq 0 ]
	[ "$output" = "debian" ]
}

@test "[fedora] rpk platform == fedora" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_run fedora rpk platform
	[ "$status" -eq 0 ]
	[ "$output" = "fedora" ]
}

@test "[arch] rpk platform == arch" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	if [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
		skip "archlinux has no official arm64 image"
	fi
	run sit_run arch rpk platform
	[ "$status" -eq 0 ]
	[ "$output" = "arch" ]
}
