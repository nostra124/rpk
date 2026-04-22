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
