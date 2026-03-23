#!/usr/bin/env bash
# git-hookd install subcommand

FORCE=false
DRY_RUN=false

for arg in "$@"; do
	case "$arg" in
	--force) FORCE=true ;;
	--dry-run) DRY_RUN=true ;;
	esac
done

ALL_HOOKS=(
	applypatch-msg commit-msg post-applypatch post-checkout
	post-commit post-merge post-receive post-rewrite post-update
	pre-applypatch pre-auto-gc pre-commit pre-merge-commit
	pre-push pre-rebase pre-receive prepare-commit-msg update
)

# Check if already installed
current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"

if [[ "$current_hooks_path" == "$GIT_HOOKD_DIR" ]]; then
	echo "git-hookd already installed at $GIT_HOOKD_DIR"
	exit 0
fi

if [[ -n "$current_hooks_path" && "$FORCE" != "true" ]]; then
	echo "Error: core.hooksPath is already set to: $current_hooks_path" >&2
	echo "Use --force to override." >&2
	exit 1
fi

if [[ "$DRY_RUN" == "true" ]]; then
	echo "[dry-run] Would create $GIT_HOOKD_DIR"
	echo "[dry-run] Would copy dispatcher and create hook symlinks"
	echo "[dry-run] Would set core.hooksPath to $GIT_HOOKD_DIR"
	echo "[dry-run] Would copy bundled modules"
	exit 0
fi

# Save previous hooksPath if forcing
if [[ -n "$current_hooks_path" && "$FORCE" == "true" ]]; then
	mkdir -p "$GIT_HOOKD_DIR"
	echo "$current_hooks_path" >"$GIT_HOOKD_DIR/.previous-hooks-path"
fi

# Create directory structure
mkdir -p "$GIT_HOOKD_DIR"

# Copy the dispatcher
cp "$GIT_HOOKD_ROOT/libexec/git-hookd/_hookd" "$GIT_HOOKD_DIR/_hookd"
chmod +x "$GIT_HOOKD_DIR/_hookd"

# Create hook symlinks
for hook in "${ALL_HOOKS[@]}"; do
	if [[ ! -L "$GIT_HOOKD_DIR/$hook" ]]; then
		ln -s _hookd "$GIT_HOOKD_DIR/$hook"
	fi
done

# Copy bundled modules
if [[ -d "$GIT_HOOKD_ROOT/modules" ]]; then
	mkdir -p "$GIT_HOOKD_DIR/modules"
	cp -R "$GIT_HOOKD_ROOT/modules/." "$GIT_HOOKD_DIR/modules/"
fi

# Set core.hooksPath
git config --global core.hooksPath "$GIT_HOOKD_DIR"

echo "git-hookd installed to $GIT_HOOKD_DIR"
