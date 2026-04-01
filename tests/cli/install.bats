#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	export GIT_HOOKD_DIR="$BATS_TEST_TMPDIR/hookd"
	export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
	touch "$GIT_CONFIG_GLOBAL"
	CLI="$PROJECT_ROOT/bin/git-hookd"
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "install creates hooks directory" {
	run "$CLI" install
	assert_success
	assert [ -d "$GIT_HOOKD_DIR" ]
}

@test "install copies dispatcher" {
	run "$CLI" install
	assert_success
	assert [ -x "$GIT_HOOKD_DIR/_hookd" ]
}

@test "install creates hook symlinks" {
	run "$CLI" install
	assert_success

	assert [ -L "$GIT_HOOKD_DIR/pre-commit" ]
	assert [ -L "$GIT_HOOKD_DIR/post-checkout" ]
	assert [ -L "$GIT_HOOKD_DIR/pre-push" ]

	# Symlinks should point to _hookd
	assert_equal "$(readlink "$GIT_HOOKD_DIR/pre-commit")" "_hookd"
	assert_equal "$(readlink "$GIT_HOOKD_DIR/post-checkout")" "_hookd"
}

@test "install sets core.hooksPath" {
	"$CLI" install
	run git config --global core.hooksPath
	assert_success
	assert_output "$GIT_HOOKD_DIR"
}

@test "install creates modules directory" {
	run "$CLI" install
	assert_success
	assert [ -d "$GIT_HOOKD_DIR/modules" ]
}

@test "install copies bundled modules" {
	run "$CLI" install
	assert_success
	assert [ -f "$GIT_HOOKD_DIR/modules/post-checkout/worktree-init.sh" ]
}

@test "install is idempotent" {
	"$CLI" install
	run "$CLI" install
	assert_success
	assert_output --partial "already installed"
}

@test "install --force re-copies modules when already installed" {
	"$CLI" install

	# Remove a module to simulate outdated install
	rm "$GIT_HOOKD_DIR/modules/post-checkout/worktree-init.sh"

	run "$CLI" install --force
	assert_success

	# Module should be restored
	assert [ -f "$GIT_HOOKD_DIR/modules/post-checkout/worktree-init.sh" ]
}

@test "install refuses when core.hooksPath is set to another directory" {
	git config --global core.hooksPath /some/other/path
	run "$CLI" install
	assert_failure
	assert_output --partial "core.hooksPath"
}

@test "install --force overrides existing core.hooksPath" {
	git config --global core.hooksPath /some/other/path
	run "$CLI" install --force
	assert_success

	run git config --global core.hooksPath
	assert_output "$GIT_HOOKD_DIR"
}

@test "install --force saves previous hooksPath" {
	git config --global core.hooksPath /some/other/path
	"$CLI" install --force

	assert [ -f "$GIT_HOOKD_DIR/.previous-hooks-path" ]
	assert_equal "$(cat "$GIT_HOOKD_DIR/.previous-hooks-path")" "/some/other/path"
}

@test "install --dry-run does not create anything" {
	run "$CLI" install --dry-run
	assert_success
	assert [ ! -d "$GIT_HOOKD_DIR" ]

	run git config --global core.hooksPath
	assert_failure
}
