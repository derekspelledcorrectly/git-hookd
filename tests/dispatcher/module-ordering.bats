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

@test "modules execute in lexicographic order" {
	mkdir -p "$GIT_HOOKD_DIR/post-checkout.d"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/90-third.sh" <<'MODULE'
#!/usr/bin/env bash
echo "third" >> "$(git rev-parse --show-toplevel)/order.log"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/90-third.sh"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/10-first.sh" <<'MODULE'
#!/usr/bin/env bash
echo "first" >> "$(git rev-parse --show-toplevel)/order.log"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/10-first.sh"

	cat >"$GIT_HOOKD_DIR/post-checkout.d/50-second.sh" <<'MODULE'
#!/usr/bin/env bash
echo "second" >> "$(git rev-parse --show-toplevel)/order.log"
MODULE
	chmod +x "$GIT_HOOKD_DIR/post-checkout.d/50-second.sh"

	cd "$REPO_DIR"
	git checkout -b test-branch --quiet

	assert [ -f "$REPO_DIR/order.log" ]
	run cat "$REPO_DIR/order.log"
	assert_line --index 0 "first"
	assert_line --index 1 "second"
	assert_line --index 2 "third"
}
