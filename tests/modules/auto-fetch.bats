#!/usr/bin/env bats
# shellcheck disable=SC2164
# Tests for the auto-fetch module, running through the git-hookd dispatcher.
#
# Strategy: We can't do real network fetches in tests. Instead, we put a
# fake `git` wrapper on PATH that logs fetch calls to a file. The wrapper
# passes through all non-fetch commands to real git.
#
# Git prepends its exec-path to PATH inside hooks, so we must also set
# GIT_EXEC_PATH to our fake-bin directory (with symlinks to real git-core
# binaries) to ensure hooks find the fake git first.

load ../test_helper

setup() {
	setup_temp_dir
	setup_hookd

	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"

	# Add a remote so auto-fetch has something to target
	git -C "$REPO_DIR" remote add origin "https://example.com/fake.git"

	# Enable the auto-fetch module
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"
	ln -s "$PROJECT_ROOT/modules/post-checkout/auto-fetch.sh" \
		"$GIT_HOOKD_DIR/post-checkout.d/50-auto-fetch.sh"

	# Create a fake git wrapper that intercepts fetch commands.
	# Symlink all real git-core binaries so git internals still work
	# when GIT_EXEC_PATH points here.
	FAKE_BIN="$BATS_TEST_TMPDIR/fake-bin"
	mkdir -p "$FAKE_BIN"
	REAL_GIT="$(which git)"
	export REAL_GIT
	FETCH_LOG="$BATS_TEST_TMPDIR/fetch.log"
	export FETCH_LOG

	local real_exec_path
	real_exec_path="$(git --exec-path)"
	for f in "$real_exec_path"/*; do
		ln -sf "$f" "$FAKE_BIN/$(basename "$f")" 2>/dev/null || true
	done
	rm -f "$FAKE_BIN/git"

	cat >"$FAKE_BIN/git" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "${1:-}" == "fetch" ]]; then
    echo "fetch $*" >>"$FETCH_LOG"
    exit 0
fi
exec "$REAL_GIT" "$@"
WRAPPER
	chmod +x "$FAKE_BIN/git"
}

teardown() {
	cd /
	teardown_temp_dir
}

# Helper: run git with the fake wrapper active
fake_git() {
	GIT_EXEC_PATH="$FAKE_BIN" PATH="$FAKE_BIN:$PATH" git "$@"
}

# --- Core behavior ---

@test "triggers fetch on branch checkout" {
	cd "$REPO_DIR"
	# Use git branch (no hook trigger) to create the branch, then checkout
	# with fake git so only one hook fires and uses our wrapper.
	git branch feature

	fake_git checkout feature --quiet
	sleep 1

	assert [ -f "$FETCH_LOG" ]
	run cat "$FETCH_LOG"
	assert_output --partial "fetch origin"
}

@test "does not trigger on file-level checkout" {
	cd "$REPO_DIR"
	echo "original" >tracked.txt
	git add tracked.txt
	git -c commit.gpgsign=false commit -m "add tracked" --quiet

	echo "changed" >tracked.txt
	fake_git checkout -- tracked.txt
	sleep 1

	assert [ ! -f "$FETCH_LOG" ]
}

# --- Cooldown ---

@test "skips fetch when FETCH_HEAD is recent (within cooldown)" {
	cd "$REPO_DIR"
	git branch feature
	git branch another

	# Create a recent FETCH_HEAD
	touch "$(git rev-parse --git-dir)/FETCH_HEAD"

	fake_git checkout feature --quiet
	sleep 1

	assert [ ! -f "$FETCH_LOG" ]
}

@test "fetches when FETCH_HEAD is older than cooldown" {
	cd "$REPO_DIR"
	git branch feature

	# Create an old FETCH_HEAD (2 minutes ago)
	fetch_head="$(git rev-parse --git-dir)/FETCH_HEAD"
	touch "$fetch_head"
	touch -t "$(date -v-2M +%Y%m%d%H%M.%S 2>/dev/null || date -d '2 minutes ago' +%Y%m%d%H%M.%S)" "$fetch_head"

	fake_git checkout feature --quiet
	sleep 1

	assert [ -f "$FETCH_LOG" ]
}

@test "fetches when FETCH_HEAD does not exist" {
	cd "$REPO_DIR"
	git branch feature

	# Ensure no FETCH_HEAD exists
	rm -f "$(git rev-parse --git-dir)/FETCH_HEAD"

	fake_git checkout feature --quiet
	sleep 1

	assert [ -f "$FETCH_LOG" ]
}

# --- Configuration ---

@test "uses configured remote" {
	cd "$REPO_DIR"
	git remote add upstream "https://example.com/upstream.git"
	git config hookd.auto-fetch.remote "upstream"
	git branch feature

	rm -f "$(git rev-parse --git-dir)/FETCH_HEAD"

	fake_git checkout feature --quiet
	sleep 1

	assert [ -f "$FETCH_LOG" ]
	run cat "$FETCH_LOG"
	assert_output --partial "fetch upstream"
}

@test "uses configured cooldown" {
	cd "$REPO_DIR"
	# Set cooldown to 0 so even a just-touched FETCH_HEAD triggers fetch
	git config hookd.auto-fetch.cooldown "0"
	git branch feature

	touch "$(git rev-parse --git-dir)/FETCH_HEAD"

	fake_git checkout feature --quiet
	sleep 1

	assert [ -f "$FETCH_LOG" ]
}

@test "invalid cooldown value falls back to default with warning" {
	cd "$REPO_DIR"
	git config hookd.auto-fetch.cooldown "five"
	git branch feature

	touch "$(git rev-parse --git-dir)/FETCH_HEAD"

	# With default 60s cooldown and a fresh FETCH_HEAD, fetch should be skipped
	fake_git checkout feature --quiet 2>"$BATS_TEST_TMPDIR/stderr"
	sleep 1

	assert [ ! -f "$FETCH_LOG" ]
	run cat "$BATS_TEST_TMPDIR/stderr"
	assert_output --partial "invalid cooldown"
}

# --- Remote name validation ---

@test "rejects remote name with slashes" {
	cd "$REPO_DIR"
	git config hookd.auto-fetch.remote "https://evil.example/repo.git"
	git branch feature

	run fake_git checkout feature --quiet
	assert_failure
	assert [ ! -f "$FETCH_LOG" ]
	assert_output --partial "invalid remote name"
}

@test "rejects remote name with spaces" {
	cd "$REPO_DIR"
	git config hookd.auto-fetch.remote "origin foo"
	git branch feature

	run fake_git checkout feature --quiet
	assert_failure
	assert [ ! -f "$FETCH_LOG" ]
	assert_output --partial "invalid remote name"
}

@test "accepts valid remote names" {
	cd "$REPO_DIR"
	git config hookd.auto-fetch.remote "my-remote_2.0"
	git branch feature

	rm -f "$(git rev-parse --git-dir)/FETCH_HEAD"

	run fake_git checkout feature --quiet
	# Should NOT trigger validation warning (will fail on get-url instead)
	refute_output --partial "invalid remote name"
	assert_output --partial "not found"
}

# --- Edge cases ---

@test "skips silently when remote does not exist" {
	cd "$REPO_DIR"
	git remote remove origin
	git branch feature

	run fake_git checkout feature --quiet
	# Should not fail (post-hook run-all, but module itself exits 0)
	assert_success
	assert [ ! -f "$FETCH_LOG" ]
	assert_output --partial "not found"
}
