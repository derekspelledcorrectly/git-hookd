#!/usr/bin/env bats
# shellcheck disable=SC2164

load ../test_helper

setup() {
	setup_temp_dir
	setup_hookd

	# Create a test repo and point it at our hookd install
	REPO_DIR=$(setup_test_repo)
	git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"
}

teardown() {
	cd /
	teardown_temp_dir
}

@test "post-checkout runs module from .d directory" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"
	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-test.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/module-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-test.sh"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/module-ran" ]
}

@test "post-checkout runs all modules even if one fails" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/10-fail.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/first-ran"
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/10-fail.sh"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/20-second.sh" <<'MODULE'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/second-ran"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/20-second.sh"

	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	# Both should have run despite first failing
	assert [ -f "$REPO_DIR/first-ran" ]
	assert [ -f "$REPO_DIR/second-ran" ]
}

@test "post-checkout chains to local hook after modules" {
	mkdir -p "$REPO_DIR/.git/hooks"
	cat >"$REPO_DIR/.git/hooks/post-checkout" <<'HOOK'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/local-hook-ran"
HOOK
	chmod +x "$REPO_DIR/.git/hooks/post-checkout"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/local-hook-ran" ]
}

@test "post-checkout chains to local hook even when module fails" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"
	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-fail.sh" <<'MODULE'
#!/usr/bin/env bash
exit 1
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-fail.sh"

	mkdir -p "$REPO_DIR/.git/hooks"
	cat >"$REPO_DIR/.git/hooks/post-checkout" <<'HOOK'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/local-hook-ran"
HOOK
	chmod +x "$REPO_DIR/.git/hooks/post-checkout"

	cd "$REPO_DIR"
	run git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/local-hook-ran" ]
}

@test "post-checkout with no .d directory still chains to local hook" {
	# No .d directory at all
	mkdir -p "$REPO_DIR/.git/hooks"
	cat >"$REPO_DIR/.git/hooks/post-checkout" <<'HOOK'
#!/usr/bin/env bash
touch "$(git rev-parse --show-toplevel)/local-hook-ran"
HOOK
	chmod +x "$REPO_DIR/.git/hooks/post-checkout"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/local-hook-ran" ]
}
