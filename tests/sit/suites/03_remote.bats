#!/usr/bin/env bats
#
# SIT 03_remote: rpk push / pull / release / sync / drop against a real
# ssh endpoint. Covers FEAT-007 acceptance criteria.
#
# Both endpoints live inside the same container:
#   rpklocal              — runs rpk, pushes/pulls
#   rpkremote@localhost   — rpk account (ssh target). Its home dir is
#                            /home/rpkremote and bare repos live under
#                            /home/rpkremote/.local/var/lib/repo/

load ../helpers

CONTAINER="rpk-sit-ssh"

setup_file() {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	sit_build_image ssh
	sit_stop_daemon "$CONTAINER"
	sit_start_daemon ssh "$CONTAINER"
	# Stage a test package inside the container as rpklocal.
	sit_exec_as "$CONTAINER" rpklocal bash -c '
		set -e
		mkdir -p $HOME/src-mypkg
		cd $HOME/src-mypkg
		git init -q -b main
		git config user.email "test@example.com"
		git config user.name  "Test User"
		echo hello > README.md
		git add README.md
		git commit -q -m "initial"
		mkdir -p ~/.local/src
		mv $HOME/src-mypkg ~/.local/src/mypkg
		cd ~/.local/src/mypkg
		rpk init >/dev/null
	'
}

teardown_file() {
	sit_stop_daemon "$CONTAINER"
}

push_via_rpklocal() {
	sit_exec_as "$CONTAINER" rpklocal bash -c "$1"
}

@test "[ssh] rpk push creates a bare repo on the remote when missing" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run push_via_rpklocal '
		cd ~/.local/src/mypkg
		rpk mypkg push rpkremote@localhost 2>&1
	'
	[ "$status" -eq 0 ]

	# The new bare repo must exist on the rpkremote user's home.
	run sit_exec_as "$CONTAINER" rpkremote test -d /home/rpkremote/.local/var/lib/repo/mypkg
	[ "$status" -eq 0 ]
}

@test "[ssh] pushed branch lands in the remote bare" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run sit_exec_as "$CONTAINER" rpkremote \
		git --git-dir=/home/rpkremote/.local/var/lib/repo/mypkg show-ref --heads
	[ "$status" -eq 0 ]
	[[ "$output" == *"refs/heads/main"* ]]
}

@test "[ssh] rpk pull from an account with no new commits is a no-op" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run push_via_rpklocal '
		cd ~/.local/src/mypkg
		rpk mypkg pull rpkremote@localhost 2>&1
	'
	[ "$status" -eq 0 ]
}

@test "[ssh] rpk drop removes the configured remote without touching others" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run push_via_rpklocal '
		cd ~/.local/src/mypkg
		# add a decoy remote that we expect to survive
		git remote remove decoy 2>/dev/null || true
		git remote add decoy https://example.com/decoy.git
		rpk mypkg drop rpkremote@localhost
		git remote
	'
	[ "$status" -eq 0 ]
	[[ "$output" == *"decoy"* ]]
	[[ "$output" != *"rpkremote@localhost"* ]]
}
