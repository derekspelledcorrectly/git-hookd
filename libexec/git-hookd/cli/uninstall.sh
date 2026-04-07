#!/usr/bin/env bash
# git-hookd uninstall subcommand

current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"
HOOKD_PATH_TILDE="~${GIT_HOOKD_DIR#"$HOME"}"

# Nothing to do if not installed
if [[ "$current_hooks_path" != "$GIT_HOOKD_DIR" && "$current_hooks_path" != "$HOOKD_PATH_TILDE" && ! -d "$GIT_HOOKD_DIR" ]]; then
	echo "git-hookd is not installed"
	exit 0
fi

# Safety: verify this looks like a hookd directory before touching anything.
# Must run BEFORE modifying core.hooksPath to avoid partial uninstall state.
if [[ -d "$GIT_HOOKD_DIR" ]]; then
	if [[ ! -f "$GIT_HOOKD_DIR/_hookd" && ! -L "$GIT_HOOKD_DIR/_hookd" ]]; then
		printf 'Error: %s does not look like a git-hookd directory, aborting\n' "$GIT_HOOKD_DIR" >&2
		exit 1
	fi
fi

# Restore previous hooksPath if we saved one
if [[ -f "$GIT_HOOKD_DIR/.previous-hooks-path" ]]; then
	previous_path="$(cat "$GIT_HOOKD_DIR/.previous-hooks-path")"
	# shellcheck disable=SC2088
	if [[ -z "$previous_path" ]]; then
		printf 'Warning: saved previous hooks path is empty, unsetting core.hooksPath\n' >&2
		git config --global --unset core.hooksPath 2>/dev/null || true
	elif [[ "$previous_path" != /* && "$previous_path" != "~/"* && "$previous_path" != "~" ]]; then
		printf 'Warning: saved previous hooks path "%s" looks suspicious, unsetting core.hooksPath instead\n' "$previous_path" >&2
		git config --global --unset core.hooksPath 2>/dev/null || true
	else
		git config --global core.hooksPath "$previous_path"
		printf 'Restored core.hooksPath to %s\n' "$previous_path"
	fi
else
	git config --global --unset core.hooksPath 2>/dev/null || true
fi

# Remove hookd directory (safety already verified above)
if [[ -d "$GIT_HOOKD_DIR" ]]; then
	rm -rf "$GIT_HOOKD_DIR"
fi

echo "git-hookd uninstalled"
