#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

# These tests exercise the full build-install-delete pipeline using a
# synthetic autoconf-like package (configure + Makefile installing a
# `hello-<pkg>` script). GNU Stow is required.

@test "package produces a bundle with the install tree" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch
	run rpk hellopkg package 0.0.2
	[ "$status" -eq 0 ]
	[ -d "$HOME/.local/pkg/hellopkg-0.0.2" ]
	[ -x "$HOME/.local/pkg/hellopkg-0.0.2/bin/hello-hellopkg" ]
}

@test "re-packaging the same version is a no-op unless forced" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch
	rpk hellopkg package 0.0.2
	local mtime_before
	mtime_before=$(stat -f "%m" "$HOME/.local/pkg/hellopkg-0.0.2/bin/hello-hellopkg" 2>/dev/null \
		|| stat -c "%Y" "$HOME/.local/pkg/hellopkg-0.0.2/bin/hello-hellopkg")
	sleep 1
	run rpk hellopkg package 0.0.2
	[ "$status" -eq 0 ]
	local mtime_after
	mtime_after=$(stat -f "%m" "$HOME/.local/pkg/hellopkg-0.0.2/bin/hello-hellopkg" 2>/dev/null \
		|| stat -c "%Y" "$HOME/.local/pkg/hellopkg-0.0.2/bin/hello-hellopkg")
	[ "$mtime_before" = "$mtime_after" ]
}

@test "install stows the bundle into the target and records the version" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch
	run rpk hellopkg install 0.0.2
	[ "$status" -eq 0 ]

	# symlink into target
	[ -L "$HOME/.local/bin/hello-hellopkg" ]
	# symlink is executable and produces the expected output
	run "$HOME/.local/bin/hello-hellopkg"
	[ "$output" = "hello from hellopkg" ]
	# install record
	[ -f "$HOME/.local/var/lib/rpk/hellopkg" ]
	run cat "$HOME/.local/var/lib/rpk/hellopkg"
	[ "$output" = "0.0.2" ]
}

@test "install without an existing bundle triggers packaging" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch
	# no explicit 'package' call — install should produce the bundle itself
	run rpk hellopkg install 0.0.2
	[ "$status" -eq 0 ]
	[ -d "$HOME/.local/pkg/hellopkg-0.0.2" ]
	[ -L "$HOME/.local/bin/hello-hellopkg" ]
}

@test "delete unstows the bundle and removes the install record" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch
	rpk hellopkg install 0.0.2
	[ -L "$HOME/.local/bin/hello-hellopkg" ]
	run rpk hellopkg delete
	[ "$status" -eq 0 ]
	[ ! -e "$HOME/.local/bin/hello-hellopkg" ]
	[ ! -f "$HOME/.local/var/lib/rpk/hellopkg" ]
}

@test "installing a newer version replaces the previous symlink" {
	make_buildable_package "hellopkg" >/dev/null
	rpk hellopkg patch              # 0.0.2
	rpk hellopkg install 0.0.2
	rpk hellopkg patch              # 0.0.3
	rpk hellopkg install 0.0.3
	# install record updated
	run cat "$HOME/.local/var/lib/rpk/hellopkg"
	[ "$output" = "0.0.3" ]
	# symlink now points at the 0.0.3 bundle
	local target
	target=$(readlink "$HOME/.local/bin/hello-hellopkg")
	[[ "$target" == *"hellopkg-0.0.3"* ]]
}
