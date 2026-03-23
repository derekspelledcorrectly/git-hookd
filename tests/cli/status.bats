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

@test "status shows version" {
	run "$CLI" status
	assert_success
	assert_output --partial "git-hookd v"
}

@test "status shows hooks directory" {
	run "$CLI" status
	assert_success
	assert_output --partial "$GIT_HOOKD_DIR"
}

@test "status shows core.hooksPath is active" {
	run "$CLI" status
	assert_success
	assert_output --partial "active"
}

@test "status shows enabled module count" {
	"$CLI" enable worktree-init
	run "$CLI" status
	assert_success
	assert_output --partial "1 module"
}
