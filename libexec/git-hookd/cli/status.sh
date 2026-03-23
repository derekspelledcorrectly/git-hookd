#!/usr/bin/env bash
# git-hookd status subcommand

echo "git-hookd v${VERSION}"
echo "Hooks directory: $GIT_HOOKD_DIR"

current_hooks_path="$(git config --global core.hooksPath 2>/dev/null || true)"
if [[ "$current_hooks_path" == "$GIT_HOOKD_DIR" ]]; then
	echo "core.hooksPath:  $current_hooks_path (active)"
else
	echo "core.hooksPath:  ${current_hooks_path:-(not set)} (inactive)"
fi

# Count enabled modules
enabled_count=0
for d_dir in "$GIT_HOOKD_DIR"/*.d; do
	[[ -d "$d_dir" ]] || continue
	for link in "$d_dir"/*; do
		[[ -L "$link" ]] && ((enabled_count++)) || true
	done
done

echo "Enabled modules: $enabled_count module(s)"
