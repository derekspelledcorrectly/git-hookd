#!/usr/bin/env bash
# git-hookd module: worktree-init
# Hook: post-checkout
# Description: Initializes new worktrees from .worktree-init manifest
set -euo pipefail

# Git passes 3 args to post-checkout: prev_ref, new_ref, checkout_type
# checkout_type=1 means branch checkout; 0 means file checkout.
# Worktree creation triggers a branch checkout.
#
# The init logic only runs for branch checkouts in secondary worktrees
# that have a .worktree-init manifest. The manifest uses INI-style
# sections: [link] for symlinks, [copy] for file copies, and [run] for
# shell commands. Sections execute in that fixed order regardless of
# their position in the file.

CHECKOUT_TYPE="${3:-0}"
[[ "$CHECKOUT_TYPE" != "1" ]] && exit 0

MAIN_WORKTREE=$(git worktree list --porcelain | awk '/^worktree/{print $2; exit}')
CURRENT_DIR="$(pwd)"

# No-op in the main worktree itself
[[ "$CURRENT_DIR" == "$MAIN_WORKTREE" ]] && exit 0

# No .worktree-init manifest? Nothing to do.
MANIFEST="$MAIN_WORKTREE/.worktree-init"
[[ -f "$MANIFEST" ]] || exit 0

# Parse sections from the manifest
link_files=()
copy_files=()
run_cmds=()
current_section=""
while IFS= read -r line || [[ -n "$line" ]]; do
	[[ -z "$line" || "$line" == \#* ]] && continue
	if [[ "$line" =~ ^\[([a-z]+)\]$ ]]; then
		current_section="${BASH_REMATCH[1]}"
		continue
	fi
	case "$current_section" in
		link) link_files+=("$line") ;;
		copy) copy_files+=("$line") ;;
		run) run_cmds+=("$line") ;;
		*)
			printf '[worktree-init] Warning: unknown section [%s] in .worktree-init, skipping\n' "$current_section" >&2
			;;
	esac
done <"$MANIFEST"

# Validate that a manifest path stays within its base directory.
# Uses python3 for portable path normalization (macOS realpath lacks -m).
path_is_contained() {
	local base="$1" rel="$2"
	local resolved
	resolved="$(python3 -c "import os,sys; print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))" "$base" "$rel")"
	case "$resolved" in
		"$base" | "$base"/*) return 0 ;;
		*) return 1 ;;
	esac
}

# Execute in fixed order: link, copy, run

for file in "${link_files[@]+"${link_files[@]}"}"; do
	# Reject paths that escape the worktree
	if ! path_is_contained "$MAIN_WORKTREE" "$file" || ! path_is_contained "$CURRENT_DIR" "$file"; then
		printf '[worktree-init] Warning: path traversal detected in "%s", skipping\n' "$file" >&2
		continue
	fi
	src="$MAIN_WORKTREE/$file"
	dst="$CURRENT_DIR/$file"
	if [[ ! -f "$src" ]]; then
		printf '[worktree-init] Warning: %s not found in main worktree, skipping\n' "$file" >&2
		continue
	fi
	if [[ -e "$dst" ]]; then
		printf '[worktree-init] Skipped %s (already exists)\n' "$file"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	printf '[worktree-init] Linked %s\n' "$file"
done

for file in "${copy_files[@]+"${copy_files[@]}"}"; do
	# Reject paths that escape the worktree
	if ! path_is_contained "$MAIN_WORKTREE" "$file" || ! path_is_contained "$CURRENT_DIR" "$file"; then
		printf '[worktree-init] Warning: path traversal detected in "%s", skipping\n' "$file" >&2
		continue
	fi
	src="$MAIN_WORKTREE/$file"
	dst="$CURRENT_DIR/$file"
	if [[ ! -f "$src" ]]; then
		printf '[worktree-init] Warning: %s not found in main worktree, skipping\n' "$file" >&2
		continue
	fi
	if [[ -e "$dst" ]]; then
		printf '[worktree-init] Skipped %s (already exists)\n' "$file"
		continue
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	printf '[worktree-init] Copied %s\n' "$file"
done

# Gate [run] commands behind explicit opt-in (like direnv allow).
# Uses standard git config precedence: local (per-repo) > global.
if [[ ${#run_cmds[@]} -gt 0 ]]; then
	run_allowed="$(git config --bool hookd.worktree-init.allow-run 2>/dev/null || echo "false")"
	if [[ "$run_allowed" != "true" ]]; then
		printf '[worktree-init] [run] commands found but execution is not allowed:\n' >&2
		for cmd in "${run_cmds[@]}"; do
			printf '[worktree-init]   %s\n' "$cmd" >&2
		done
		printf '[worktree-init] To allow for this repo: git config hookd.worktree-init.allow-run true\n' >&2
		printf '[worktree-init] To allow globally:      git config --global hookd.worktree-init.allow-run true\n' >&2
		exit 1
	fi
fi

rc=0
for cmd in "${run_cmds[@]+"${run_cmds[@]}"}"; do
	printf '[worktree-init] Running: %s\n' "$cmd"
	(cd "$CURRENT_DIR" && bash -c "$cmd") || rc=$?
	if [[ "$rc" -ne 0 ]]; then
		printf '[worktree-init] Command failed (exit %d): %s\n' "$rc" "$cmd"
		exit "$rc"
	fi
done
