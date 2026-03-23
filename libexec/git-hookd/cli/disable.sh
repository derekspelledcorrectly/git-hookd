#!/usr/bin/env bash
# git-hookd disable subcommand

MODULE_SPEC="${1:-}"
if [[ -z "$MODULE_SPEC" ]]; then
	echo "Usage: git hookd disable <module>" >&2
	exit 1
fi

# Resolve module name (strip hook/ prefix if present)
if [[ "$MODULE_SPEC" == */* ]]; then
	MODULE_NAME="${MODULE_SPEC#*/}"
else
	MODULE_NAME="$MODULE_SPEC"
fi

# Validate module name (no path traversal)
if [[ "$MODULE_NAME" == *..* || "$MODULE_NAME" == */* ]]; then
	printf 'Error: invalid module name "%s"\n' "$MODULE_NAME" >&2
	exit 1
fi

# Find and remove symlinks matching this module in any .d directory
found=false
for d_dir in "$GIT_HOOKD_DIR"/*.d; do
	[[ -d "$d_dir" ]] || continue
	for link in "$d_dir"/*-"${MODULE_NAME}.sh"; do
		if [[ -L "$link" ]]; then
			rm "$link"
			echo "Disabled $MODULE_NAME (removed $(basename "$link") from $(basename "$d_dir"))"
			found=true
		fi
	done
done

if [[ "$found" != "true" ]]; then
	echo "Error: module '$MODULE_NAME' is not enabled" >&2
	exit 1
fi
