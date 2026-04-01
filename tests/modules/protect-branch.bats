#!/usr/bin/env bats
# shellcheck disable=SC2164
# Tests for the protect-branch module, running through the git-hookd dispatcher.

load ../test_helper

setup() {
	setup_temp_dir
	setup_hookd

	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"

	# Enable the protect-branch module
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	ln -s "$PROJECT_ROOT/modules/pre-commit/protect-branch.sh" \
		"$GIT_HOOKD_DIR/pre-commit.d/50-protect-branch.sh"
}

teardown() {
	cd /
	teardown_temp_dir
}

# --- Default protected branches ---

@test "blocks commit on main" {
	cd "$REPO_DIR"
	# setup_test_repo already creates on main
	echo "change" >file.txt
	git add file.txt

	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "protected branch"
	assert_output --partial "HOOKD_ALLOW_PROTECTED"
}

@test "blocks commit on master" {
	cd "$REPO_DIR"
	git branch -m main master
	echo "change" >file.txt
	git add file.txt

	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "protected branch"
}

# --- Allow and override ---

@test "allows commit on feature branch" {
	cd "$REPO_DIR"
	git checkout -b feature/my-thing --quiet
	echo "change" >file.txt
	git add file.txt

	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_success
}

@test "allows commit in detached HEAD" {
	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	HOOKD_ALLOW_PROTECTED=1 git -c commit.gpgsign=false commit -m "setup" --quiet

	git checkout --detach --quiet
	echo "another" >file2.txt
	git add file2.txt

	run git -c commit.gpgsign=false commit -m "detached" --quiet
	assert_success
}

@test "HOOKD_ALLOW_PROTECTED=1 overrides protection" {
	cd "$REPO_DIR"
	# Already on main from setup_test_repo
	echo "change" >file.txt
	git add file.txt

	run env HOOKD_ALLOW_PROTECTED=1 git -c commit.gpgsign=false commit -m "hotfix" --quiet
	assert_success
}

@test "HOOKD_ALLOW_PROTECTED=yes does not bypass protection" {
	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt

	run env HOOKD_ALLOW_PROTECTED=yes git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "protected branch"
}

# --- Custom patterns ---

@test "custom patterns via git config replace defaults" {
	cd "$REPO_DIR"
	git config hookd.protect-branch.pattern "develop"

	# main should now be allowed (defaults replaced)
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_success

	# develop should be blocked
	git checkout -b develop --quiet
	echo "change2" >file2.txt
	git add file2.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "protected branch"
}

@test "glob patterns match branches" {
	cd "$REPO_DIR"
	git config hookd.protect-branch.pattern "release/*"

	git checkout -b release/v1.2 --quiet
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "protected branch"
}

@test "blocks commit when git config returns unexpected error (fail-closed)" {
	cd "$REPO_DIR"
	git checkout -b feature/safe --quiet

	# Create a fake git that returns exit code 3 on config --get-all for
	# our key, simulating a corrupted config. All other commands pass through.
	FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin"
	mkdir -p "$FAKE_BIN"
	REAL_GIT="$(which git)"

	local real_exec_path
	real_exec_path="$(git --exec-path)"
	for f in "$real_exec_path"/*; do
		ln -sf "$f" "$FAKE_BIN/$(basename "$f")" 2>/dev/null || true
	done
	rm -f "$FAKE_BIN/git"

	cat >"$FAKE_BIN/git" <<WRAPPER
#!/usr/bin/env bash
if [[ "\${1:-}" == "config" && "\${2:-}" == "--get-all" && "\${3:-}" == "hookd.protect-branch.pattern" ]]; then
    echo "fatal: bad config" >&2
    exit 3
fi
exec "$REAL_GIT" "\$@"
WRAPPER
	chmod +x "$FAKE_BIN/git"

	echo "change" >file.txt
	git add file.txt

	run env GIT_EXEC_PATH="$FAKE_BIN" PATH="$FAKE_BIN:$PATH" \
		git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure
	assert_output --partial "ERROR"
	assert_output --partial "safety measure"
}

@test "multiple custom patterns via git config" {
	cd "$REPO_DIR"
	git config hookd.protect-branch.pattern "staging"
	git config --add hookd.protect-branch.pattern "production"

	git checkout -b staging --quiet
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure

	git checkout -b production --quiet
	echo "change2" >file2.txt
	git add file2.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_failure

	# feature branch should be allowed
	git checkout -b feature/ok --quiet
	echo "change3" >file3.txt
	git add file3.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet
	assert_success
}
