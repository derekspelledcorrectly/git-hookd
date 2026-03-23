#!/usr/bin/env bats
# shellcheck disable=SC2164
# Tests for the worktree-init module, running through the git-hookd dispatcher.

load ../test_helper

setup() {
	setup_temp_dir
	setup_hookd

	# Create a test repo and point it at our hookd install
	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"

	# Enable the worktree-init module
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"
	ln -s "$PROJECT_ROOT/modules/post-checkout/worktree-init.sh" \
		"$GIT_HOOKD_DIR/post-checkout.d/50-worktree-init.sh"
}

teardown() {
	cd /
	teardown_temp_dir
}

# --- [link] section ---

@test "[link] symlinks listed files into new worktree" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init
	git branch wt-branch --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt" wt-branch --quiet
	assert_success

	assert [ -L "$BATS_TEST_TMPDIR/wt/.env" ]
	# Use realpath to normalize /var vs /private/var on macOS
	assert_equal "$(realpath "$(readlink "$BATS_TEST_TMPDIR/wt/.env")")" "$(realpath "$REPO_DIR/.env")"
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt/.env")" "SECRET=abc"
}

@test "[link] does not overwrite existing files" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init
	git branch wt-exist --quiet

	git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-exist" wt-exist --quiet

	# Replace symlink with a real file
	rm "$BATS_TEST_TMPDIR/wt-exist/.env"
	echo "SECRET=modified" >"$BATS_TEST_TMPDIR/wt-exist/.env"

	# Re-trigger via branch checkout
	cd "$BATS_TEST_TMPDIR/wt-exist"
	run git checkout -b another --quiet

	assert_output --partial "Skipped .env"
	assert [ ! -L "$BATS_TEST_TMPDIR/wt-exist/.env" ]
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt-exist/.env")" "SECRET=modified"
}

@test "[link] does not overwrite existing symlinks" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init
	git branch wt-exist-link --quiet

	git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-exist-link" wt-exist-link --quiet
	assert [ -L "$BATS_TEST_TMPDIR/wt-exist-link/.env" ]

	cd "$BATS_TEST_TMPDIR/wt-exist-link"
	run git checkout -b another --quiet

	assert_output --partial "Skipped .env"
	assert [ -L "$BATS_TEST_TMPDIR/wt-exist-link/.env" ]
}

@test "[link] creates parent directories for nested paths" {
	cd "$REPO_DIR"
	mkdir -p config
	echo "NESTED=true" >config/.env
	printf '[link]\nconfig/.env\n' >.worktree-init
	git branch wt-nested --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-nested" wt-nested --quiet
	assert_success

	assert [ -L "$BATS_TEST_TMPDIR/wt-nested/config/.env" ]
	assert_equal "$(realpath "$(readlink "$BATS_TEST_TMPDIR/wt-nested/config/.env")")" "$(realpath "$REPO_DIR/config/.env")"
}

@test "[link] symlink reflects changes to source file" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init
	git branch wt-reflect --quiet

	git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-reflect" wt-reflect --quiet

	echo "SECRET=updated" >"$REPO_DIR/.env"
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt-reflect/.env")" "SECRET=updated"
}

@test "[link] warns and skips when source file does not exist" {
	cd "$REPO_DIR"
	printf '[link]\nnonexistent.txt\n' >.worktree-init
	git branch wt-link-missing --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-link-missing" wt-link-missing --quiet
	assert_success
	assert [ ! -e "$BATS_TEST_TMPDIR/wt-link-missing/nonexistent.txt" ]
	assert_output --partial "Warning: nonexistent.txt not found"
}

# --- [copy] section ---

@test "[copy] copies file into new worktree" {
	cd "$REPO_DIR"
	echo '{}' >settings.json
	printf '[copy]\nsettings.json\n' >.worktree-init
	git branch wt-copy --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-copy" wt-copy --quiet
	assert_success

	assert [ -f "$BATS_TEST_TMPDIR/wt-copy/settings.json" ]
	assert [ ! -L "$BATS_TEST_TMPDIR/wt-copy/settings.json" ]
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt-copy/settings.json")" "{}"
}

@test "[copy] source changes do not propagate to copy" {
	cd "$REPO_DIR"
	echo '{}' >settings.json
	printf '[copy]\nsettings.json\n' >.worktree-init
	git branch wt-copy-iso --quiet

	git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-copy-iso" wt-copy-iso --quiet

	echo '{"updated": true}' >"$REPO_DIR/settings.json"
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt-copy-iso/settings.json")" "{}"
}

@test "[copy] does not overwrite existing file" {
	cd "$REPO_DIR"
	echo '{}' >settings.json
	printf '[copy]\nsettings.json\n' >.worktree-init
	git branch wt-copy-exist --quiet

	git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-copy-exist" wt-copy-exist --quiet

	echo '{"local": true}' >"$BATS_TEST_TMPDIR/wt-copy-exist/settings.json"

	cd "$BATS_TEST_TMPDIR/wt-copy-exist"
	run git checkout -b another --quiet

	assert_output --partial "Skipped settings.json"
	assert_equal "$(cat "$BATS_TEST_TMPDIR/wt-copy-exist/settings.json")" '{"local": true}'
}

@test "[copy] warns and skips when source file does not exist" {
	cd "$REPO_DIR"
	printf '[copy]\nnonexistent.txt\n' >.worktree-init
	git branch wt-copy-missing --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-copy-missing" wt-copy-missing --quiet
	assert_success
	assert [ ! -e "$BATS_TEST_TMPDIR/wt-copy-missing/nonexistent.txt" ]
	assert_output --partial "Warning: nonexistent.txt not found"
}

# --- [run] section ---

@test "[run] executes command in worktree root" {
	cd "$REPO_DIR"
	printf '[run]\ntouch marker.txt\n' >.worktree-init
	git branch wt-run --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-run" wt-run --quiet
	assert_success
	assert [ -f "$BATS_TEST_TMPDIR/wt-run/marker.txt" ]
}

@test "[run] failing command stops execution" {
	cd "$REPO_DIR"
	cat >.worktree-init <<'MANIFEST'
[run]
false
touch should-not-exist.txt
MANIFEST
	git branch wt-run-fail --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-run-fail" wt-run-fail --quiet
	assert_failure

	assert [ ! -f "$BATS_TEST_TMPDIR/wt-run-fail/should-not-exist.txt" ]
	assert_output --partial "Command failed"
}

# --- Manifest parsing ---

@test "skips blank lines and comments in .worktree-init" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	cat >.worktree-init <<'LIST'
[link]
# This is a comment

.env

# Another comment
LIST
	git branch wt-comments --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-comments" wt-comments --quiet
	assert_success
	assert [ -L "$BATS_TEST_TMPDIR/wt-comments/.env" ]
}

@test "unknown sections warn and are skipped" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	cat >.worktree-init <<'MANIFEST'
[future]
something-unknown

[link]
.env
MANIFEST
	git branch wt-unknown --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-unknown" wt-unknown --quiet
	assert_success
	assert [ -L "$BATS_TEST_TMPDIR/wt-unknown/.env" ]
	assert_output --partial "Warning: unknown section [future]"
}

@test "lines before first section header are ignored" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	cat >.worktree-init <<'MANIFEST'
this line has no section
neither does this
[link]
.env
MANIFEST
	git branch wt-preamble --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-preamble" wt-preamble --quiet
	assert_success
	assert [ -L "$BATS_TEST_TMPDIR/wt-preamble/.env" ]
}

@test "all three sections execute in order" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	echo '{}' >settings.json
	cat >.worktree-init <<'MANIFEST'
[link]
.env

[copy]
settings.json

[run]
touch marker.txt
MANIFEST
	git branch wt-all --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-all" wt-all --quiet
	assert_success

	assert [ -L "$BATS_TEST_TMPDIR/wt-all/.env" ]
	assert [ -f "$BATS_TEST_TMPDIR/wt-all/settings.json" ]
	assert [ ! -L "$BATS_TEST_TMPDIR/wt-all/settings.json" ]
	assert [ -f "$BATS_TEST_TMPDIR/wt-all/marker.txt" ]
}

# --- Behavioral guards ---

@test "no-op when running in the main worktree" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init

	git checkout -b main-branch --quiet

	assert [ -f "$REPO_DIR/.env" ]
	assert [ ! -L "$REPO_DIR/.env" ]
}

@test "no-op on file-level checkout" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	printf '[link]\n.env\n' >.worktree-init

	echo "original" >tracked.txt
	git add tracked.txt && git -c commit.gpgsign=false commit -m "add tracked" --quiet

	echo "changed" >tracked.txt
	git checkout -- tracked.txt

	assert_equal "$(cat tracked.txt)" "original"
}

@test "skips silently when no .worktree-init exists" {
	cd "$REPO_DIR"
	echo "SECRET=abc" >.env
	git branch wt-no-manifest --quiet

	run git -c commit.gpgsign=false worktree add "$BATS_TEST_TMPDIR/wt-no-manifest" wt-no-manifest --quiet
	assert_success
	assert [ ! -e "$BATS_TEST_TMPDIR/wt-no-manifest/.env" ]
}
