#!/usr/bin/env bash
set -euo pipefail

# git-hookd installer
# Usage: curl -fsSL https://raw.githubusercontent.com/derekspelledcorrectly/git-hookd/main/install.sh | bash

GIT_HOOKD_DIR="${GIT_HOOKD_DIR:-$HOME/.local/share/git-hookd}"
REPO="derekspelledcorrectly/git-hookd"

printf 'Installing git-hookd to %s...\n' "$GIT_HOOKD_DIR"

# Require git
if ! command -v git >/dev/null 2>&1; then
	printf 'Error: git is required to install git-hookd\n' >&2
	exit 1
fi

if [[ -d "$GIT_HOOKD_DIR/.git" ]]; then
	printf 'Updating existing installation...\n'
	if ! git -C "$GIT_HOOKD_DIR" pull --quiet; then
		printf 'Error: failed to update git-hookd\n' >&2
		exit 1
	fi
else
	if ! git clone --quiet "https://github.com/${REPO}.git" "$GIT_HOOKD_DIR"; then
		printf 'Error: failed to clone git-hookd repository\n' >&2
		exit 1
	fi
fi

# Ensure CLI is on PATH
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if [[ ! -L "$BIN_DIR/git-hookd" ]]; then
	ln -s "$GIT_HOOKD_DIR/bin/git-hookd" "$BIN_DIR/git-hookd"
	printf 'Linked git-hookd to %s/git-hookd\n' "$BIN_DIR"
fi

# Check if ~/.local/bin is on PATH
if ! printf '%s\n' "$PATH" | tr ':' '\n' | grep -qF "$BIN_DIR"; then
	printf 'Warning: %s is not in your PATH\n' "$BIN_DIR"
	# shellcheck disable=SC2016
	printf 'Add it to your shell config: export PATH="$HOME/.local/bin:$PATH"\n'
fi

# Run install
"$GIT_HOOKD_DIR/bin/git-hookd" install "$@"

printf '\nDone! Run "git hookd list" to see available modules.\n'
printf 'Enable the worktree-init module: git hookd enable worktree-init\n'
