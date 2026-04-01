#!/usr/bin/env bash
# git-hookd module: auto-fetch
# Hook: post-checkout
# Description: Background fetch after branch checkout to keep remote refs fresh
set -euo pipefail

# Git passes 3 args to post-checkout: prev_ref, new_ref, checkout_type
# checkout_type=1 means branch checkout; 0 means file checkout.
CHECKOUT_TYPE="${3:-0}"
[[ "$CHECKOUT_TYPE" != "1" ]] && exit 0

# Read config
remote="$(git config hookd.auto-fetch.remote 2>/dev/null || echo "origin")"
cooldown="$(git config hookd.auto-fetch.cooldown 2>/dev/null || echo "60")"
if ! [[ "$cooldown" =~ ^[0-9]+$ ]]; then
	printf '[auto-fetch] Warning: invalid cooldown "%s", using default 60s\n' "$cooldown" >&2
	cooldown=60
fi

# Verify remote exists
if ! git remote get-url "$remote" >/dev/null 2>&1; then
	printf '[auto-fetch] Warning: remote "%s" not found or unreadable, skipping\n' "$remote" >&2
	exit 0
fi

# Check cooldown via FETCH_HEAD mtime
git_dir="$(git rev-parse --git-dir)"
fetch_head="$git_dir/FETCH_HEAD"
if [[ -f "$fetch_head" ]]; then
	last_fetch=$(stat -c %Y "$fetch_head" 2>/dev/null || stat -f %m "$fetch_head" 2>/dev/null || echo 0)
	now=$(date +%s)
	if ((now - last_fetch < cooldown)); then
		exit 0
	fi
fi

printf '[auto-fetch] Fetching from %s in background\n' "$remote"
(git fetch "$remote" --quiet >/dev/null &)

exit 0
