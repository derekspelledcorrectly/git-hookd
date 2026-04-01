# tests/test_helper.bash - Shared setup for bats tests
#
# Loads bats-support and bats-assert from vendored submodules.
# Provides temp dir management and a minimal git-hookd install helper.

# Load bats helper libraries (vendored as git submodules)
TEST_HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/test_helper" && pwd)"
load "${TEST_HELPER_DIR}/bats-support/load.bash"
load "${TEST_HELPER_DIR}/bats-assert/load.bash"

# Project root (parent of tests/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_ROOT

# Create a temp dir for test fixtures (cleaned up in teardown)
setup_temp_dir() {
	BATS_TEST_TMPDIR="$(mktemp -d)"
	export BATS_TEST_TMPDIR
}

teardown_temp_dir() {
	if [[ -d "${BATS_TEST_TMPDIR:-}" ]]; then
		rm -rf "$BATS_TEST_TMPDIR"
	fi
}

# Set up a minimal git-hookd install in a temp directory.
# Creates the dispatcher, hook symlinks, and module directories.
# Sets GIT_HOOKD_DIR and configures the test repo to use it.
setup_hookd() {
	local hookd_dir="$BATS_TEST_TMPDIR/hookd"
	mkdir -p "$hookd_dir"

	# Copy the dispatcher
	cp "$PROJECT_ROOT/libexec/git-hookd/_hookd" "$hookd_dir/_hookd"
	chmod +x "$hookd_dir/_hookd"

	# Create symlinks for standard hook names
	local hooks=(
		applypatch-msg commit-msg post-applypatch post-checkout
		post-commit post-merge post-receive post-rewrite post-update
		pre-applypatch pre-auto-gc pre-commit pre-merge-commit
		pre-push pre-rebase pre-receive prepare-commit-msg update
	)
	for hook in "${hooks[@]}"; do
		ln -s _hookd "$hookd_dir/$hook"
	done

	export GIT_HOOKD_DIR="$hookd_dir"
}

# Create a git repo in the temp dir with one initial commit.
setup_test_repo() {
	local repo_dir="${1:-$BATS_TEST_TMPDIR/repo}"
	git init "$repo_dir" --quiet
	# Bypass global hooks for the seed commit so tests aren't affected
	# by whatever modules the user has enabled (e.g. protect-branch).
	git -C "$repo_dir" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
		commit --allow-empty -m "init" --quiet
	echo "$repo_dir"
}
