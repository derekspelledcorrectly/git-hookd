#!/usr/bin/env bash
# git-hookd install subcommand

FORCE=false
DRY_RUN=false

for arg in "$@"; do
	case "$arg" in
		--force) FORCE=true ;;
		--dry-run) DRY_RUN=true ;;
		*)
			printf 'Error: unknown option "%s"\n' "$arg" >&2
			exit 1
			;;
	esac
done

ALL_HOOKS=(
	applypatch-msg commit-msg post-applypatch post-checkout
	post-commit post-merge post-receive post-rewrite post-update
	pre-applypatch pre-auto-gc pre-commit pre-merge-commit
	pre-push pre-rebase pre-receive prepare-commit-msg update
)

# Check if already installed (compare both absolute and tilde forms)
current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"
HOOKD_PATH_TILDE="${GIT_HOOKD_DIR/#"$HOME"/\~}"

if [[ "$current_hooks_path" == "$GIT_HOOKD_DIR" || "$current_hooks_path" == "$HOOKD_PATH_TILDE" ]]; then
	if [[ "$FORCE" != "true" ]]; then
		echo "git-hookd already installed at $GIT_HOOKD_DIR"
		exit 0
	fi
elif [[ -n "$current_hooks_path" && "$FORCE" != "true" ]]; then
	echo "Error: core.hooksPath is already set to: $current_hooks_path" >&2
	echo "Use --force to override." >&2
	exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
	echo "[dry-run] Would create $GIT_HOOKD_DIR"
	echo "[dry-run] Would copy dispatcher and create hook symlinks"
	echo "[dry-run] Would set core.hooksPath to $GIT_HOOKD_DIR"
	echo "[dry-run] Would copy bundled modules"
	echo "[dry-run] Would copy completion scripts"
	exit 0
fi

# Save previous hooksPath if forcing
if [[ -n "$current_hooks_path" && "$FORCE" == "true" ]]; then
	mkdir -p "$GIT_HOOKD_DIR"
	echo "$current_hooks_path" >"$GIT_HOOKD_DIR/.previous-hooks-path"
fi

# Create directory structure
mkdir -p "$GIT_HOOKD_DIR"

# When GIT_HOOKD_ROOT == GIT_HOOKD_DIR (e.g. chezmoi external), skip copying
HOOKD_ROOT_REAL="$(cd "$GIT_HOOKD_ROOT" && pwd -P)"
HOOKD_DIR_REAL="$(cd "$GIT_HOOKD_DIR" && pwd -P)"

# Copy the full project tree (dispatcher, CLI, bin entry point)
if [[ "$HOOKD_ROOT_REAL" != "$HOOKD_DIR_REAL" ]]; then
	cp "$GIT_HOOKD_ROOT/libexec/git-hookd/_hookd" "$GIT_HOOKD_DIR/_hookd"
	chmod +x "$GIT_HOOKD_DIR/_hookd"

	mkdir -p "$GIT_HOOKD_DIR/libexec/git-hookd/cli"
	cp "$GIT_HOOKD_ROOT"/libexec/git-hookd/cli/*.sh "$GIT_HOOKD_DIR/libexec/git-hookd/cli/"

	mkdir -p "$GIT_HOOKD_DIR/bin"
	cp "$GIT_HOOKD_ROOT/bin/git-hookd" "$GIT_HOOKD_DIR/bin/git-hookd"
	chmod +x "$GIT_HOOKD_DIR/bin/git-hookd"
else
	# In-place install: symlink dispatcher from libexec
	if [[ ! -L "$GIT_HOOKD_DIR/_hookd" ]]; then
		ln -sf "libexec/git-hookd/_hookd" "$GIT_HOOKD_DIR/_hookd"
	fi
fi

# Create hook symlinks
for hook in "${ALL_HOOKS[@]}"; do
	if [[ ! -L "$GIT_HOOKD_DIR/$hook" ]]; then
		ln -s _hookd "$GIT_HOOKD_DIR/$hook"
	fi
done

# Copy bundled modules (skip when installing in-place)
if [[ "$HOOKD_ROOT_REAL" != "$HOOKD_DIR_REAL" && -d "$GIT_HOOKD_ROOT/modules" ]]; then
	mkdir -p "$GIT_HOOKD_DIR/modules"
	cp -R "$GIT_HOOKD_ROOT/modules/." "$GIT_HOOKD_DIR/modules/"
fi

# Copy completion scripts (skip when installing in-place)
if [[ "$HOOKD_ROOT_REAL" != "$HOOKD_DIR_REAL" ]]; then
	if [[ -d "$GIT_HOOKD_ROOT/completions" ]]; then
		mkdir -p "$GIT_HOOKD_DIR/completions"
		cp "$GIT_HOOKD_ROOT"/completions/* "$GIT_HOOKD_DIR/completions/"
	fi
fi

# Set core.hooksPath (use ~ for portability and to match what users write in configs)
HOOKD_PATH_FOR_CONFIG="${GIT_HOOKD_DIR/#"$HOME"/\~}"
git config --global core.hooksPath "$HOOKD_PATH_FOR_CONFIG"

# Offer to install shell completions
if { printf '' >/dev/tty; } 2>/dev/null; then
	printf '\nShell completions are available for bash and zsh.\n'
	printf 'Install completions now? [y/N] ' >/dev/tty
	if read -r answer </dev/tty 2>/dev/null; then
		case "$answer" in
			[yY] | [yY][eE][sS])
				# Source completions subcommand with --install
				source "$GIT_HOOKD_ROOT/libexec/git-hookd/cli/completions.sh" --install
				;;
			*)
				printf 'Completions can be installed later with: git hookd completions --install\n'
				;;
		esac
	else
		printf 'Completions can be installed later with: git hookd completions --install\n'
	fi
else
	printf 'Completions can be installed later with: git hookd completions --install\n'
fi

echo "git-hookd installed to $GIT_HOOKD_DIR"
