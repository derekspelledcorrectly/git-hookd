#!/usr/bin/env bash
# git-hookd uninstall subcommand

current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"

# Nothing to do if not installed
if [[ "$current_hooks_path" != "$GIT_HOOKD_DIR" && ! -d "$GIT_HOOKD_DIR" ]]; then
	echo "git-hookd is not installed"
	exit 0
fi

# Restore previous hooksPath if we saved one
if [[ -f "$GIT_HOOKD_DIR/.previous-hooks-path" ]]; then
	previous_path="$(cat "$GIT_HOOKD_DIR/.previous-hooks-path")"
	if [[ -z "$previous_path" ]]; then
		printf 'Warning: saved previous hooks path is empty, unsetting core.hooksPath\n' >&2
		git config --global --unset core.hooksPath 2>/dev/null || true
	else
		git config --global core.hooksPath "$previous_path"
		printf 'Restored core.hooksPath to %s\n' "$previous_path"
	fi
else
	git config --global --unset core.hooksPath 2>/dev/null || true
fi

# Remove the hooks directory
if [[ -d "$GIT_HOOKD_DIR" ]]; then
	rm -rf "$GIT_HOOKD_DIR"
fi

echo "git-hookd uninstalled"
