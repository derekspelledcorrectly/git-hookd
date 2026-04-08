#!/usr/bin/env bash
# git-hookd status subcommand

echo "git-hookd v${VERSION}"
echo "Hooks directory: $GIT_HOOKD_DIR"

current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"
# Match both expanded ($HOME/...) and tilde (~/..) forms
HOOKD_PATH_TILDE="${GIT_HOOKD_DIR/#"$HOME"/\~}"
if [[ "$current_hooks_path" == "$GIT_HOOKD_DIR" || "$current_hooks_path" == "$HOOKD_PATH_TILDE" ]]; then
	echo "core.hooksPath:  $current_hooks_path (active)"
else
	echo "core.hooksPath:  ${current_hooks_path:-(not set)} (inactive)"
fi

# Warn if core.hooksPath is set to a foreign value (possible clobbering)
if [[ -n "$current_hooks_path" && "$current_hooks_path" != "$GIT_HOOKD_DIR" && "$current_hooks_path" != "$HOOKD_PATH_TILDE" ]]; then
	echo ""
	echo "WARNING: core.hooksPath has been changed to: $current_hooks_path"
	echo "  This may have been set by another tool (husky, lefthook, etc.)"
	echo "  To restore git-hookd:  git hookd install --force"
	echo "  To safely run tools:   git hookd exec -- <command>"
fi

# Count enabled modules
enabled_count=0
for d_dir in "$GIT_HOOKD_DIR"/*.d; do
	[[ -d "$d_dir" ]] || continue
	for link in "$d_dir"/*; do
		if [[ -L "$link" ]]; then
			enabled_count=$((enabled_count + 1))
		fi
	done
done

echo "Enabled modules: $enabled_count module(s)"
