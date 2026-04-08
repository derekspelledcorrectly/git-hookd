#!/usr/bin/env bash
# git-hookd exec subcommand
# Temporarily unset core.hooksPath, run a command, then restore it.
# This lets tools like husky/lefthook install without clobbering git-hookd.

# Strip optional leading --
[[ "${1:-}" == "--" ]] && shift

if [[ $# -eq 0 ]]; then
	echo "Usage: git hookd exec [--] <command> [args...]" >&2
	exit 1
fi

saved="$(git config --global core.hooksPath 2>/dev/null || true)"

restore() {
	if [[ -n "$saved" ]]; then
		if ! git config --global core.hooksPath "$saved"; then
			echo "ERROR: Failed to restore core.hooksPath to: $saved" >&2
			echo "  Run manually: git config --global core.hooksPath '$saved'" >&2
		fi
	else
		git config --global --unset core.hooksPath 2>/dev/null || true
	fi
}
trap restore EXIT

git config --global --unset core.hooksPath 2>/dev/null || true
"$@"
