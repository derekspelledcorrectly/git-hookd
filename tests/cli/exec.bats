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

@test "exec restores core.hooksPath after command" {
	run "$CLI" exec -- true
	assert_success
	run git config --global core.hooksPath
	assert_success
	assert_output "$GIT_HOOKD_DIR"
}

@test "exec unsets core.hooksPath during command" {
	run "$CLI" exec -- git config --global core.hooksPath
	assert_failure
}

@test "exec propagates exit code from command" {
	run "$CLI" exec -- false
	assert_failure
	[[ "$status" -eq 1 ]]
}

@test "exec restores core.hooksPath after command failure" {
	run "$CLI" exec -- false
	run git config --global core.hooksPath
	assert_success
	assert_output "$GIT_HOOKD_DIR"
}

@test "exec works without -- separator" {
	run "$CLI" exec true
	assert_success
	run git config --global core.hooksPath
	assert_success
	assert_output "$GIT_HOOKD_DIR"
}

@test "exec prints usage with no arguments" {
	run "$CLI" exec
	assert_failure
	assert_output --partial "Usage:"
}

@test "exec keeps hooksPath unset when it was never set" {
	git config --global --unset core.hooksPath
	run "$CLI" exec -- true
	assert_success
	run git config --global core.hooksPath
	assert_failure
}
