#!/usr/bin/env bats
#
# SIT 04_release: `rpk <pkg> release <account>` against a two-container
# setup where the receiver has NO pre-installed rpk. Verifies that
# release's scp step actually ships the upstream binary and that the
# remote `/tmp/rpk <pkg> update` invocation deploys the package end-to-end.
# Covers FEAT-008.

load ../helpers

NETWORK="rpk-sit-net"
UPSTREAM="rpk-sit-upstream"
RECEIVER="rpk-sit-receiver"

setup_file() {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	sit_build_image ssh-upstream
	sit_build_image ssh-receiver

	podman stop "$UPSTREAM" "$RECEIVER" >/dev/null 2>&1 || true
	podman rm -f "$UPSTREAM" "$RECEIVER" >/dev/null 2>&1 || true
	podman network rm "$NETWORK" >/dev/null 2>&1 || true
	podman network create "$NETWORK" >/dev/null

	podman run -d --rm \
		--network "$NETWORK" --network-alias receiver \
		--name "$RECEIVER" "rpk-sit:ssh-receiver" >/dev/null
	podman run -d --rm \
		--network "$NETWORK" \
		--name "$UPSTREAM" "rpk-sit:ssh-upstream" >/dev/null
	# Give sshd time to bind.
	sleep 2
}

teardown_file() {
	podman stop --time 1 "$UPSTREAM" "$RECEIVER" >/dev/null 2>&1 || true
	podman rm -f "$UPSTREAM" "$RECEIVER" >/dev/null 2>&1 || true
	podman network rm "$NETWORK" >/dev/null 2>&1 || true
}

upstream_exec() {
	podman exec --user rpklocal "$UPSTREAM" bash -c "$1"
}

receiver_exec() {
	podman exec "$RECEIVER" "$@"
}

@test "[release] precondition: receiver has no rpk yet" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	# rpk must not be in any of the usual PATH locations on the receiver.
	run receiver_exec sh -c '[ ! -x /usr/local/bin/rpk ] && [ ! -x /usr/bin/rpk ] && [ ! -x /bin/rpk ]'
	[ "$status" -eq 0 ]
}

@test "[release] upstream can ssh to rpkremote@receiver" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run upstream_exec 'ssh rpkremote@receiver echo pong'
	[ "$status" -eq 0 ]
	[[ "$output" == *"pong"* ]]
}

@test "[release] rpk mypkg release rpkremote@receiver succeeds" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run upstream_exec '
		cd ~/.local/src/mypkg
		rpk mypkg release rpkremote@receiver 2>&1
	'
	[ "$status" -eq 0 ]
}

@test "[release] /tmp/rpk on receiver is byte-identical to upstream's rpk" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	local upstream_sum receiver_sum
	upstream_sum=$(podman exec "$UPSTREAM" sha256sum /usr/local/bin/rpk | awk '{print $1}')
	receiver_sum=$(receiver_exec sha256sum /tmp/rpk | awk '{print $1}')
	[ -n "$upstream_sum" ]
	[ "$upstream_sum" = "$receiver_sum" ]
}

@test "[release] package bundle was built on receiver" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run receiver_exec test -d /home/rpkremote/.local/pkg/mypkg-0.0.2
	[ "$status" -eq 0 ]
}

@test "[release] hello-mypkg binary got stowed into receiver's target" {
	command -v podman >/dev/null 2>&1 || skip "podman not installed"
	run receiver_exec test -L /home/rpkremote/.local/bin/hello-mypkg
	[ "$status" -eq 0 ]
	run receiver_exec /home/rpkremote/.local/bin/hello-mypkg
	[ "$status" -eq 0 ]
	[[ "$output" == *"hello from mypkg"* ]]
}
