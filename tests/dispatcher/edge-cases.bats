#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	setup_hookd

	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "skips non-executable files in .d directory" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	# Non-executable file -- should be skipped
	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-readme.txt" <<'FILE'
This is not a module
FILE

	# Executable module -- should run
	cat >"$GIT_HOOKD_DIR/post-checkout.d/60-real.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/real-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/60-real.sh"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/real-ran" ]
}

@test "warns on broken symlinks and continues" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	# Broken symlink
	ln -s /nonexistent/module.sh "$GIT_HOOKD_DIR/post-checkout.d/10-broken.sh"

	# Working module after the broken one
	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-real.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/real-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-real.sh"

	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	# Should warn about broken symlink
	assert_output --partial "broken symlink"
	# Should still run the working module
	assert [ -f "$REPO_DIR/real-ran" ]
}

@test "empty .d directory is a no-op" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	assert_success
}

@test "no .d directory is a no-op" {
	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	assert_success
}

@test "modules receive hook arguments" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"
	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-args.sh" <<'MODULE'
#!/usr/bin/env bash
# post-checkout receives: prev_ref new_ref checkout_type
echo "$@" > "$(git rev-parse --show-toplevel)/hook-args"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-args.sh"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/hook-args" ]
	# Should have 3 args: prev_ref new_ref checkout_type(1)
	run cat "$REPO_DIR/hook-args"
	# The line should end with " 1" (branch checkout type)
	assert_output --regexp ' 1$'
}

@test "hookd.skip skips named module" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-skipped.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/skipped-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-skipped.sh"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/60-kept.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/kept-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/60-kept.sh"

	cd "$REPO_DIR"
	git config hookd.skip "skipped"

	git checkout -b test-branch --quiet

	assert [ ! -f "$REPO_DIR/skipped-ran" ]
	assert [ -f "$REPO_DIR/kept-ran" ]
}

@test "hookd.skip supports multiple values" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"

	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-first.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/first-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-first.sh"

	cat >"$GIT_HOOKD_DIR/pre-commit.d/60-second.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/second-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/60-second.sh"

	cat >"$GIT_HOOKD_DIR/pre-commit.d/70-third.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/third-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/70-third.sh"

	cd "$REPO_DIR"
	git config hookd.skip "first"
	git config --add hookd.skip "third"

	echo "change" >file.txt
	git add file.txt
	git -c commit.gpgsign=false commit -m "test" --quiet

	assert [ ! -f "$REPO_DIR/first-ran" ]
	assert [ -f "$REPO_DIR/second-ran" ]
	assert [ ! -f "$REPO_DIR/third-ran" ]
}

@test "hook with no modules and no local hook exits 0" {
	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	assert_success
}
