#!/usr/bin/env bash
set -euo pipefail

# git-hookd installer
# Usage: curl -fsSL https://raw.githubusercontent.com/derekspelledcorrectly/git-hookd/main/install.sh | bash

GIT_HOOKD_DIR="${GIT_HOOKD_DIR:-$HOME/.local/share/git-hookd}"
REPO="derekspelledcorrectly/git-hookd"
BRANCH="main"

echo "Installing git-hookd to $GIT_HOOKD_DIR..."

# Prefer git clone; fall back to tarball download
if command -v git >/dev/null 2>&1; then
	if [[ -d "$GIT_HOOKD_DIR/.git" ]]; then
		echo "Updating existing installation..."
		git -C "$GIT_HOOKD_DIR" pull --quiet
	else
		git clone --quiet "https://github.com/${REPO}.git" "$GIT_HOOKD_DIR"
	fi
else
	echo "Error: git is required to install git-hookd" >&2
	exit 1
fi

# Ensure CLI is on PATH
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if [[ ! -L "$BIN_DIR/git-hookd" ]]; then
	ln -s "$GIT_HOOKD_DIR/bin/git-hookd" "$BIN_DIR/git-hookd"
	echo "Linked git-hookd to $BIN_DIR/git-hookd"
fi

# Check if ~/.local/bin is on PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "$BIN_DIR"; then
	echo "Warning: $BIN_DIR is not in your PATH"
	echo "Add it to your shell config: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Run install
"$GIT_HOOKD_DIR/bin/git-hookd" install "$@"

echo ""
echo "Done! Run 'git hookd list' to see available modules."
echo "Enable the worktree-init module: git hookd enable worktree-init"
