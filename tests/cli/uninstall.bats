#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	export GIT_HOOKD_DIR="$BATS_TEST_TMPDIR/hookd"
	export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
	touch "$GIT_CONFIG_GLOBAL"
	CLI="$PROJECT_ROOT/bin/git-hookd"

	# Install first so we have something to uninstall
	"$CLI" install
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "uninstall removes hooks directory" {
	"$CLI" uninstall
	assert [ ! -d "$GIT_HOOKD_DIR" ]
}

@test "uninstall unsets core.hooksPath" {
	"$CLI" uninstall
	run git config --global core.hooksPath
	assert_failure
}

@test "uninstall restores previous hooksPath when saved" {
	# Reinstall with --force over a previous path
	git config --global core.hooksPath /previous/path
	"$CLI" install --force

	"$CLI" uninstall
	run git config --global core.hooksPath
	assert_success
	assert_output "/previous/path"
}

@test "uninstall is safe when not installed" {
	"$CLI" uninstall
	# Already uninstalled, running again should be safe
	run "$CLI" uninstall
	assert_success
}
