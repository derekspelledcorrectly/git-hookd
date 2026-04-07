#!/usr/bin/env bash
set -euo pipefail

# git-hookd installer
# Usage: curl -fsSL https://raw.githubusercontent.com/derekspelledcorrectly/git-hookd/main/install.sh | bash

GIT_HOOKD_DIR="${GIT_HOOKD_DIR:-$HOME/.local/share/git-hookd}"
REPO_URL="https://github.com/derekspelledcorrectly/git-hookd.git"

# Require git
if ! command -v git >/dev/null 2>&1; then
	printf 'Error: git is required to install git-hookd\n' >&2
	exit 1
fi

# --- Chezmoi detection ---

install_mode="standard"

if command -v chezmoi >/dev/null 2>&1; then
	CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || true)"
	if [[ -n "$CHEZMOI_SOURCE" ]]; then
		printf 'Detected chezmoi (source: %s)\n\n' "$CHEZMOI_SOURCE"
		printf 'git-hookd can integrate with chezmoi so new machines get it automatically.\n'
		printf 'This would:\n'
		printf '  1. Add a .chezmoiexternal.toml entry to pull git-hookd on chezmoi apply\n'
		printf '  2. Add a chezmoi-managed symlink at ~/.local/bin/git-hookd\n'
		printf '  3. Create a run_onchange script to set up hooks on apply\n'
		printf '  4. Run chezmoi apply to complete the install\n'
		printf '\n'
		printf 'Options:\n'
		printf '  [c] Install with chezmoi integration (recommended)\n'
		printf '  [s] Standard install (skip chezmoi, just clone + symlink)\n'
		printf '  [q] Quit\n'
		printf '\n'

		while true; do
			printf 'Choice [c/s/q]: '
			read -r choice </dev/tty
			case "$choice" in
				c | C) install_mode="chezmoi" && break ;;
				s | S) install_mode="standard" && break ;;
				q | Q) printf 'Aborted.\n' && exit 0 ;;
				*) printf 'Please enter c, s, or q.\n' ;;
			esac
		done
	fi
fi

# --- Chezmoi install ---

if [[ "$install_mode" == "chezmoi" ]]; then
	printf '\nSetting up chezmoi integration...\n'

	EXTERNAL_FILE="$CHEZMOI_SOURCE/.chezmoiexternal.toml"

	# 1. Add .chezmoiexternal.toml entry
	if [[ -f "$EXTERNAL_FILE" ]] && grep -qF "git-hookd" "$EXTERNAL_FILE"; then
		printf 'chezmoi external entry already exists, skipping.\n'
	else
		{
			printf '\n# git-hookd: modular global git hooks framework\n'
			printf '[".local/share/git-hookd"]\n'
			printf '    type = "git-repo"\n'
			printf '    url = "%s"\n' "$REPO_URL"
			printf '    refreshPeriod = "168h"\n'
		} >>"$EXTERNAL_FILE"
		printf 'Added .chezmoiexternal.toml entry.\n'
	fi

	# 2. Add hooksPath to chezmoi-managed git config template (if present)
	GIT_CONFIG_TMPL=""
	for candidate in "$CHEZMOI_SOURCE/dot_config/git/config.tmpl" \
		"$CHEZMOI_SOURCE/dot_gitconfig.tmpl" \
		"$CHEZMOI_SOURCE/private_dot_gitconfig.tmpl"; do
		if [[ -f "$candidate" ]]; then
			GIT_CONFIG_TMPL="$candidate"
			break
		fi
	done

	if [[ -n "$GIT_CONFIG_TMPL" ]]; then
		if grep -q 'hooksPath.*git-hookd' "$GIT_CONFIG_TMPL"; then
			printf 'hooksPath already in git config template, skipping.\n'
		elif grep -q '^\[core\]' "$GIT_CONFIG_TMPL"; then
			# Insert hooksPath after [core] section header
			tmpfile="$(mktemp)"
			sed '/^\[core\]/a\
	hooksPath = ~/.local/share/git-hookd
' "$GIT_CONFIG_TMPL" >"$tmpfile" && mv "$tmpfile" "$GIT_CONFIG_TMPL"
			printf 'Added hooksPath to git config template.\n'
		else
			printf 'Warning: no [core] section found in %s\n' "$GIT_CONFIG_TMPL" >&2
			printf 'Please add manually: hooksPath = ~/.local/share/git-hookd\n' >&2
		fi
	else
		printf 'No chezmoi-managed git config template found.\n'
		printf 'The run_onchange script will set core.hooksPath on apply.\n'
	fi

	# 3. Create run_onchange script (handles symlink + install)
	RUN_SCRIPT="$CHEZMOI_SOURCE/run_onchange_install-git-hookd.sh.tmpl"
	if [[ -f "$RUN_SCRIPT" ]]; then
		printf 'run_onchange script already exists, skipping.\n'
	else
		cat >"$RUN_SCRIPT" <<'SCRIPT'
#!/usr/bin/env bash
# git-hookd: run on chezmoi apply when the external repo changes
# {{ $hookd := joinPath .chezmoi.homeDir ".local/share/git-hookd/libexec/git-hookd/_hookd" -}}
# hash: {{ if stat $hookd }}{{ include $hookd | sha256sum }}{{ else }}not-yet-installed{{ end }}
set -euo pipefail

HOOKD="$HOME/.local/share/git-hookd"

# Ensure CLI symlink exists
BIN_DIR="$HOME/.local/bin"
if [[ ! -L "$BIN_DIR/git-hookd" ]]; then
    mkdir -p "$BIN_DIR"
    ln -s "$HOOKD/bin/git-hookd" "$BIN_DIR/git-hookd"
fi

# Set up dispatcher and core.hooksPath
if [[ -x "$HOOKD/bin/git-hookd" ]]; then
    "$HOOKD/bin/git-hookd" install
fi
SCRIPT
		chmod +x "$RUN_SCRIPT"
		printf 'Created run_onchange_install-git-hookd.sh.tmpl.\n'
	fi

	# 4. Tell the user to finish up
	printf '\nChezmoi source files are ready. To complete the install:\n\n'
	printf '  1. chezmoi apply\n'
	printf '  2. git hookd enable worktree-init\n'
	printf '  3. Commit the changes in your chezmoi repo\n\n'
	printf 'On future machines, "chezmoi apply" will set up git-hookd automatically.\n'
	exit 0
fi

# --- Standard install ---

printf 'Installing git-hookd to %s...\n' "$GIT_HOOKD_DIR"

if [[ -d "$GIT_HOOKD_DIR/.git" ]]; then
	printf 'Updating existing installation...\n'
	if ! git -C "$GIT_HOOKD_DIR" pull --quiet; then
		printf 'Error: failed to update git-hookd\n' >&2
		exit 1
	fi
else
	if ! git clone --quiet "$REPO_URL" "$GIT_HOOKD_DIR"; then
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
