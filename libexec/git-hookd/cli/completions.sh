#!/usr/bin/env bash
# git-hookd completions subcommand

INSTALL=false
SHELL_ARG=""

# Parse flags
for arg in "$@"; do
	case "$arg" in
		--install) INSTALL=true ;;
		--*)
			printf 'Error: unknown option "%s"\n' "$arg" >&2
			printf 'Usage: git hookd completions [--install] [bash|zsh]\n' >&2
			exit 1
			;;
		*) SHELL_ARG="$arg" ;;
	esac
done

# Detect shell if not specified
if [[ -z "$SHELL_ARG" ]]; then
	if [[ -n "${SHELL:-}" ]]; then
		SHELL_ARG="$(basename "$SHELL")"
	else
		printf 'Error: could not detect shell. Please specify a shell: git hookd completions [bash|zsh]\n' >&2
		exit 1
	fi
fi

# Validate shell
case "$SHELL_ARG" in
	bash | zsh) ;;
	*)
		printf 'Unsupported shell: %s (supported: bash, zsh)\n' "$SHELL_ARG" >&2
		exit 1
		;;
esac

# Resolve completion script path
if [[ "$SHELL_ARG" == "bash" ]]; then
	COMP_FILE="$GIT_HOOKD_ROOT/completions/git-hookd.bash"
else
	COMP_FILE="$GIT_HOOKD_ROOT/completions/_git-hookd"
fi

# Also check installed location as fallback
if [[ ! -f "$COMP_FILE" ]]; then
	if [[ "$SHELL_ARG" == "bash" ]]; then
		COMP_FILE="$GIT_HOOKD_DIR/completions/git-hookd.bash"
	else
		COMP_FILE="$GIT_HOOKD_DIR/completions/_git-hookd"
	fi
fi

if [[ ! -f "$COMP_FILE" ]]; then
	printf 'Error: completion script not found for %s\n' "$SHELL_ARG" >&2
	exit 1
fi

if [[ "$INSTALL" == "true" ]]; then
	if [[ "$SHELL_ARG" == "bash" ]]; then
		DEST_DIR="$HOME/.local/share/bash-completion/completions"
		DEST="$DEST_DIR/git-hookd"
		mkdir -p "$DEST_DIR"
		cp "$COMP_FILE" "$DEST"
		DEST_DISPLAY="${DEST/#"$HOME"/\~}"
		printf 'Installed bash completions to %s\n' "$DEST_DISPLAY"
		printf 'Requires: bash-completion package (brew install bash-completion@2)\n'
		printf 'If bash-completion is not installed, add to ~/.bashrc:\n'
		printf '  source %s\n' "$DEST_DISPLAY"
		printf 'Restart your shell to activate.\n'
	else
		DEST_DIR="$HOME/.zsh/completions"
		DEST="$DEST_DIR/_git-hookd"
		mkdir -p "$DEST_DIR"
		cp "$COMP_FILE" "$DEST"
		# Also install _git_hookd for Homebrew git-completion.bash wrapper
		GIT_SUBCMD_FILE="${COMP_FILE%/*}/_git_hookd"
		if [[ ! -f "$GIT_SUBCMD_FILE" ]]; then
			GIT_SUBCMD_FILE="$GIT_HOOKD_DIR/completions/_git_hookd"
		fi
		if [[ -f "$GIT_SUBCMD_FILE" ]]; then
			cp "$GIT_SUBCMD_FILE" "$DEST_DIR/_git_hookd"
		fi
		DEST_DISPLAY="${DEST/#"$HOME"/\~}"
		printf 'Installed zsh completions to %s\n' "$DEST_DISPLAY"
		printf 'Requires fpath entry in ~/.zshrc (add before compinit):\n'
		# shellcheck disable=SC2016
		printf '  fpath=(~/.zsh/completions $fpath)\n'
		printf 'Restart your shell or run: exec zsh\n'
	fi
else
	cat "$COMP_FILE"
fi
