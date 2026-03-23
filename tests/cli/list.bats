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

@test "list shows available modules" {
	run "$CLI" list
	assert_success
	assert_output --partial "worktree-init"
}

@test "list shows module as disabled when not enabled" {
	run "$CLI" list
	assert_success
	assert_output --partial "disabled"
}

@test "list shows module as enabled after enable" {
	"$CLI" enable worktree-init
	run "$CLI" list
	assert_success
	assert_output --partial "enabled"
}

@test "list groups modules by hook event" {
	run "$CLI" list
	assert_success
	assert_output --partial "post-checkout"
}
