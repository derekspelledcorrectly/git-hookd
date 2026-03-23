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

@test "pre-commit runs module from .d directory" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-test.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/module-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-test.sh"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	git -c commit.gpgsign=false commit -m "test" --quiet

	assert [ -f "$REPO_DIR/module-ran" ]
}

@test "pre-commit failure blocks the commit" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-block.sh" <<'MODULE'
#!/usr/bin/env bash
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-block.sh"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet

	assert_failure
}

@test "pre-commit fail-fast skips remaining modules" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"

	cat >"$GIT_HOOKD_DIR/pre-commit.d/10-fail.sh" <<'MODULE'
#!/usr/bin/env bash
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/10-fail.sh"

	cat >"$GIT_HOOKD_DIR/pre-commit.d/20-second.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/second-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/20-second.sh"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet

	assert_failure
	# Second module should NOT have run
	assert [ ! -f "$REPO_DIR/second-ran" ]
}

@test "pre-commit failure does not chain to local hook" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-block.sh" <<'MODULE'
#!/usr/bin/env bash
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-block.sh"

	mkdir -p "$REPO_DIR/.git/hooks"
	cat >"$REPO_DIR/.git/hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/local-hook-ran"
HOOK
	chmod +x "$REPO_DIR/.git/hooks/pre-commit"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet

	assert_failure
	assert [ ! -f "$REPO_DIR/local-hook-ran" ]
}

@test "pre-commit failure reports specific exit code" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-fail7.sh" <<'MODULE'
#!/usr/bin/env bash
exit 7
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-fail7.sh"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet

	assert_failure
	assert_output --partial "failed (exit 7)"
}

@test "commit-msg gets pre-hook fail-fast semantics" {
	mkdir -p "$GIT_HOOKD_DIR/commit-msg.d"

	cat >"$GIT_HOOKD_DIR/commit-msg.d/10-block.sh" <<'MODULE'
#!/usr/bin/env bash
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/commit-msg.d/10-block.sh"

	cat >"$GIT_HOOKD_DIR/commit-msg.d/20-second.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/second-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/commit-msg.d/20-second.sh"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	run git -c commit.gpgsign=false commit -m "test" --quiet

	assert_failure
	# Second module should NOT have run (fail-fast)
	assert [ ! -f "$REPO_DIR/second-ran" ]
}

@test "pre-commit success chains to local hook" {
	mkdir -p "$GIT_HOOKD_DIR/pre-commit.d"
	cat >"$GIT_HOOKD_DIR/pre-commit.d/50-pass.sh" <<'MODULE'
#!/usr/bin/env bash
exit 0
MODULE
	chmod +x "$GIT_HOOKD_DIR/pre-commit.d/50-pass.sh"

	mkdir -p "$REPO_DIR/.git/hooks"
	cat >"$REPO_DIR/.git/hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/local-hook-ran"
HOOK
	chmod +x "$REPO_DIR/.git/hooks/pre-commit"

	cd "$REPO_DIR"
	echo "change" >file.txt
	git add file.txt
	git -c commit.gpgsign=false commit -m "test" --quiet

	assert [ -f "$REPO_DIR/local-hook-ran" ]
}
