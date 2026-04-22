#!/usr/bin/env bats

load helpers

setup()    { sandbox_setup; }
teardown() { sandbox_teardown; }

@test "depends on a package with an empty depends/ dir is a no-op success" {
	make_package "mypkg" >/dev/null
	run rpk mypkg depends
	[ "$status" -eq 0 ]
}

@test "depends runs a single scaffolded dependency script" {
	local repo
	repo=$(make_package "mypkg")
	# Dependency script writes a marker file on success.
	cat > "$repo/.rpk/depends/widget" <<MARKER
#!/bin/bash
touch "$SANDBOX/widget-ran"
MARKER
	chmod +x "$repo/.rpk/depends/widget"

	run rpk mypkg depends
	[ "$status" -eq 0 ]
	[ -f "$SANDBOX/widget-ran" ]
}

@test "depends runs multiple scripts in alphabetical order" {
	local repo
	repo=$(make_package "mypkg")
	for dep in charlie alpha bravo; do
		cat > "$repo/.rpk/depends/$dep" <<MARKER
#!/bin/bash
echo "$dep" >> "$SANDBOX/run-order"
MARKER
		chmod +x "$repo/.rpk/depends/$dep"
	done

	run rpk mypkg depends
	[ "$status" -eq 0 ]
	run cat "$SANDBOX/run-order"
	local expected="alpha
bravo
charlie"
	[ "$output" = "$expected" ]
}

@test "depends continues past a failing script" {
	local repo
	repo=$(make_package "mypkg")
	cat > "$repo/.rpk/depends/broken" <<'MARKER'
#!/bin/bash
exit 42
MARKER
	chmod +x "$repo/.rpk/depends/broken"
	cat > "$repo/.rpk/depends/later" <<MARKER
#!/bin/bash
touch "$SANDBOX/later-ran"
MARKER
	chmod +x "$repo/.rpk/depends/later"

	run rpk mypkg depends
	[ "$status" -eq 0 ]
	[ -f "$SANDBOX/later-ran" ]
}

@test "depends on a system package fatals for a non-root user" {
	local repo
	repo=$(make_package "mypkg")
	echo "system" > "$repo/.rpk/type"
	# Leave the depends/ directory populated so rpk actually enters the
	# root-check branch (which only runs when depends/ exists).
	cat > "$repo/.rpk/depends/dummy" <<'MARKER'
#!/bin/bash
exit 0
MARKER
	chmod +x "$repo/.rpk/depends/dummy"

	run rpk mypkg depends
	[ "$status" -ne 0 ]
	[[ "$output" == *"system packages"* ]]
}

@test "depends on an unstaged package fatals" {
	run rpk mypkg depends
	[ "$status" -ne 0 ]
}
