#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	export GIT_HOOKD_DIR="$BATS_TEST_TMPDIR/hookd"
	export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
	touch "$GIT_CONFIG_GLOBAL"
	CLI="$PROJECT_ROOT/bin/git-hookd"
	"$CLI" install
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "enable creates symlink in correct .d directory" {
	run "$CLI" enable worktree-init
	assert_success

	assert [ -d "$GIT_HOOKD_DIR/post-checkout.d" ]
	assert [ -L "$GIT_HOOKD_DIR/post-checkout.d/50-worktree-init.sh" ]
}

@test "enable symlink points to module in library" {
	"$CLI" enable worktree-init

	local target
	target="$(readlink "$GIT_HOOKD_DIR/post-checkout.d/50-worktree-init.sh")"
	assert_equal "$target" "$GIT_HOOKD_DIR/modules/post-checkout/worktree-init.sh"
}

@test "enable with explicit hook/module form" {
	run "$CLI" enable post-checkout/worktree-init
	assert_success
	assert [ -L "$GIT_HOOKD_DIR/post-checkout.d/50-worktree-init.sh" ]
}

@test "enable with --priority sets custom prefix" {
	run "$CLI" enable --priority 10 worktree-init
	assert_success
	assert [ -L "$GIT_HOOKD_DIR/post-checkout.d/10-worktree-init.sh" ]
}

@test "enable nonexistent module fails" {
	run "$CLI" enable nonexistent
	assert_failure
	assert_output --partial "not found"
}

@test "enable already-enabled module is idempotent" {
	"$CLI" enable worktree-init
	run "$CLI" enable worktree-init
	assert_success
	assert_output --partial "already enabled"
}

@test "disable removes symlink" {
	"$CLI" enable worktree-init
	run "$CLI" disable worktree-init
	assert_success

	# Symlink should be gone
	run find "$GIT_HOOKD_DIR" -name "*worktree-init*" -type l
	assert_output ""
}

@test "disable nonexistent module fails gracefully" {
	run "$CLI" disable nonexistent
	assert_failure
	assert_output --partial "not enabled"
}
