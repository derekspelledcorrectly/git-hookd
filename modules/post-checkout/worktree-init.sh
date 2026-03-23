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
	*) ;; # Unknown sections are silently ignored for forward compatibility
	esac
done <"$MANIFEST"

# Execute in fixed order: link, copy, run

for file in "${link_files[@]+"${link_files[@]}"}"; do
	src="$MAIN_WORKTREE/$file"
	dst="$CURRENT_DIR/$file"
	if [[ ! -f "$src" ]]; then
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
	src="$MAIN_WORKTREE/$file"
	dst="$CURRENT_DIR/$file"
	if [[ ! -f "$src" ]]; then
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

rc=0
for cmd in "${run_cmds[@]+"${run_cmds[@]}"}"; do
	printf '[worktree-init] Running: %s\n' "$cmd"
	(cd "$CURRENT_DIR" && bash -c "$cmd") || rc=$?
	if [[ "$rc" -ne 0 ]]; then
		printf '[worktree-init] Command failed (exit %d): %s\n' "$rc" "$cmd"
		exit "$rc"
	fi
done
