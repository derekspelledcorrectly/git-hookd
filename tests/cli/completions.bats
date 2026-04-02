#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	export GIT_HOOKD_DIR="$BATS_TEST_TMPDIR/hookd"
	export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/gitconfig"
	touch "$GIT_CONFIG_GLOBAL"
	CLI="$PROJECT_ROOT/bin/git-hookd"

	# Create minimal completions dir so the subcommand can find scripts
	mkdir -p "$BATS_TEST_TMPDIR/hookd/completions"
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "completions with explicit 'bash' dumps bash script to stdout" {
	run "$CLI" completions bash
	assert_success
	assert_output --partial '_git_hookd'
}

@test "completions with explicit 'zsh' dumps zsh script to stdout" {
	run "$CLI" completions zsh
	assert_success
	assert_output --partial 'compdef'
}

@test "completions infers shell from SHELL env var" {
	SHELL=/bin/zsh run "$CLI" completions
	assert_success
	assert_output --partial 'compdef'
}

@test "completions infers bash from SHELL env var" {
	SHELL=/bin/bash run "$CLI" completions
	assert_success
	assert_output --partial '_git_hookd'
}

@test "completions errors on unknown shell" {
	run "$CLI" completions fish
	assert_failure
	assert_output --partial 'Unsupported shell'
}

@test "completions errors when shell cannot be detected" {
	SHELL="" run "$CLI" completions
	assert_failure
	assert_output --partial 'specify a shell'
}

@test "completions appears in usage output" {
	run "$CLI" --help
	assert_success
	assert_output --partial 'completions'
}

@test "bash completion script defines _git_hookd function" {
	run "$CLI" completions bash
	assert_success
	assert_output --partial '_git_hookd()'
}

@test "bash completion script registers standalone completion" {
	run "$CLI" completions bash
	assert_success
	assert_output --partial 'complete -F'
	assert_output --partial 'git-hookd'
}

@test "zsh completion script defines _git-hookd function" {
	run "$CLI" completions zsh
	assert_success
	assert_output --partial '#compdef git-hookd'
}

@test "zsh completion script includes module completion" {
	run "$CLI" completions zsh
	assert_success
	assert_output --partial '_git_hookd_modules'
}

@test "completions --install bash copies to bash-completion dir" {
	export HOME="$BATS_TEST_TMPDIR/fakehome"
	mkdir -p "$HOME"
	run "$CLI" completions --install bash
	assert_success
	assert [ -f "$HOME/.local/share/bash-completion/completions/git-hookd" ]
	assert_output --partial 'Installed bash completions'
	assert_output --partial 'bash-completion'
}

@test "completions --install zsh copies to zsh completions dir" {
	export HOME="$BATS_TEST_TMPDIR/fakehome"
	mkdir -p "$HOME"
	run "$CLI" completions --install zsh
	assert_success
	assert [ -f "$HOME/.zsh/completions/_git-hookd" ]
	assert_output --partial 'Installed zsh completions'
	assert_output --partial 'fpath'
}
