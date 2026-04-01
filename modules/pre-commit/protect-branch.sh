#!/usr/bin/env bash
# git-hookd module: protect-branch
# Hook: pre-commit
# Description: Prevents commits on protected branches
set -euo pipefail

# Override escape hatch
[[ "${HOOKD_ALLOW_PROTECTED:-}" == "1" ]] && exit 0

# Detached HEAD is fine
branch="$(git symbolic-ref --short HEAD 2>/dev/null)" || exit 0

# Read protected patterns from git config; fall back to main + master.
# Distinguish "key not found" (exit 1, normal) from "config broken" (other
# exit codes). A security hook must fail closed on unexpected errors.
if config_output="$(git config --get-all hookd.protect-branch.pattern 2>&1)"; then
	mapfile -t patterns <<<"$config_output"
else
	rc=$?
	if [[ $rc -eq 1 ]]; then
		patterns=("main" "master")
	else
		printf '[protect-branch] ERROR: failed to read git config (exit %d): %s\n' "$rc" "$config_output" >&2
		printf '[protect-branch] Blocking commit as a safety measure.\n' >&2
		exit 1
	fi
fi

for pattern in "${patterns[@]}"; do
	# shellcheck disable=SC2254
	case "$branch" in
		$pattern)
			printf "[protect-branch] Commit blocked: '%s' is a protected branch.\n" "$branch" >&2
			printf '[protect-branch] To override: HOOKD_ALLOW_PROTECTED=1 git commit ...\n' >&2
			exit 1
			;;
	esac
done

exit 0
