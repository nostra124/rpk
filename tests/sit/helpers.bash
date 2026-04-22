# Shared helpers for SIT (system integration) bats tests.
#
# Each suite assumes `podman` is available. Tests that need a specific
# distro image build it on demand via `sit_build_image <distro>` and run
# containers through `sit_run <distro> <cmd…>`.

: "${SIT_REPO_ROOT:=$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)}"
: "${SIT_DIR:=${SIT_REPO_ROOT}/tests/sit}"

# sit_build_image <distro> — idempotently build the rpk-sit:<distro> image
# from the Dockerfile at tests/sit/podman/Dockerfile.<distro>. Uses the
# repo root as context so the image has the full source tree available.
sit_build_image() {
	local distro=$1
	local tag="rpk-sit:$distro"
	local dockerfile="$SIT_DIR/podman/Dockerfile.$distro"
	[ -f "$dockerfile" ] || {
		echo "sit_build_image: no Dockerfile for '$distro' at $dockerfile" >&2
		return 1
	}
	podman build -q -t "$tag" -f "$dockerfile" "$SIT_REPO_ROOT" >/dev/null
}

# sit_run <distro> <cmd…> — run a command inside the built image, removing
# the container afterwards. Stdout/stderr stream back to bats as normal.
sit_run() {
	local distro=$1; shift
	podman run --rm "rpk-sit:$distro" "$@"
}

# sit_start_daemon <distro> <name> — start a long-running container (e.g.
# the ssh-enabled image) and echo its id. The image's CMD runs in the
# foreground. Caller is responsible for sit_stop_daemon.
sit_start_daemon() {
	local distro=$1 name=$2
	podman run -d --rm --name "$name" "rpk-sit:$distro" >/dev/null
	# Give sshd a moment to bind.
	sleep 1
}

sit_stop_daemon() {
	local name=$1
	podman stop --time 1 "$name" >/dev/null 2>&1 || true
	podman rm -f "$name" >/dev/null 2>&1 || true
}

# sit_exec_as <container> <user> <cmd…> — run a command inside a running
# container as the given user.
sit_exec_as() {
	local container=$1 user=$2; shift 2
	podman exec --user "$user" "$container" "$@"
}
