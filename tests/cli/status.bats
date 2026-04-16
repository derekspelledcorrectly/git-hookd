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

@test "status warns when core.hooksPath is clobbered" {
	git config --global core.hooksPath "/tmp/some-other-tool"
	run "$CLI" status
	assert_success
	assert_output --partial "WARNING"
	assert_output --partial "/tmp/some-other-tool"
	assert_output --partial "git hookd install --force"
	assert_output --partial "git hookd exec"
}

@test "status does not warn when core.hooksPath is unset" {
	git config --global --unset core.hooksPath
	run env -C "$BATS_TEST_TMPDIR" "$CLI" status
	assert_success
	refute_output --partial "WARNING"
}

@test "status warns when local repo overrides core.hooksPath" {
	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "/tmp/some-local-hooks"
	run env -C "$REPO_DIR" "$CLI" status
	assert_success
	assert_output --partial "WARNING"
	assert_output --partial "local"
	assert_output --partial "/tmp/some-local-hooks"
}

@test "status does not warn when local hooksPath matches git-hookd" {
	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"
	run env -C "$REPO_DIR" "$CLI" status
	assert_success
	refute_output --partial "local"
}

@test "status detects active when hooksPath uses tilde form" {
	# install.sh stores with ~ prefix; status should recognize it as active
	git config --global core.hooksPath "~/.local/share/git-hookd"
	run env -C "$BATS_TEST_TMPDIR" env GIT_HOOKD_DIR="$HOME/.local/share/git-hookd" "$CLI" status
	assert_success
	assert_output --partial "active"
	refute_output --partial "WARNING"
}
