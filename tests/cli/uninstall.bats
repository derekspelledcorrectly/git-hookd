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

@test "uninstall refuses to rm -rf a directory without _hookd" {
	# Simulate a GIT_HOOKD_DIR pointing at a non-hookd directory
	rm "$GIT_HOOKD_DIR/_hookd"
	rm -f "$GIT_HOOKD_DIR"/pre-commit "$GIT_HOOKD_DIR"/post-checkout
	run "$CLI" uninstall
	assert_failure
	assert_output --partial "does not look like a git-hookd directory"
}

@test "uninstall warns on suspicious previous hooks path" {
	# Write a suspicious (relative) path to the saved file
	echo "relative/path" >"$GIT_HOOKD_DIR/.previous-hooks-path"
	run "$CLI" uninstall
	assert_success
	assert_output --partial "looks suspicious"
	# core.hooksPath should be unset, not set to the bad value
	run git config --global core.hooksPath
	assert_failure
}

@test "uninstall detects hookd via tilde path" {
	# Set core.hooksPath to the tilde form (as install does)
	HOOKD_PATH_TILDE="~${GIT_HOOKD_DIR#"$HOME"}"
	git config --global core.hooksPath "$HOOKD_PATH_TILDE"
	run "$CLI" uninstall
	assert_success
	assert_output --partial "uninstalled"
}
