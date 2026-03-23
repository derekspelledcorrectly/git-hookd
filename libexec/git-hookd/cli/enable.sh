#!/usr/bin/env bash
# git-hookd enable subcommand

PRIORITY=50

# Parse flags
ARGS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
	--priority)
		if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
			printf 'Error: --priority requires a positive integer\n' >&2
			exit 1
		fi
		PRIORITY="$2"
		shift 2
		;;
	*)
		ARGS+=("$1")
		shift
		;;
	esac
done

MODULE_SPEC="${ARGS[0]:-}"
if [[ -z "$MODULE_SPEC" ]]; then
	echo "Usage: git hookd enable [--priority N] <module>" >&2
	exit 1
fi

# Resolve module: either "hook/module" or just "module" (auto-discover)
if [[ "$MODULE_SPEC" == */* ]]; then
	HOOK_EVENT="${MODULE_SPEC%%/*}"
	MODULE_NAME="${MODULE_SPEC#*/}"
else
	MODULE_NAME="$MODULE_SPEC"
	HOOK_EVENT=""

	# Auto-discover which hook event this module belongs to
	for hook_dir in "$GIT_HOOKD_DIR"/modules/*/; do
		[[ -d "$hook_dir" ]] || continue
		if [[ -f "$hook_dir/$MODULE_NAME.sh" ]]; then
			HOOK_EVENT="$(basename "$hook_dir")"
			break
		fi
	done
fi

# Validate names (no path traversal)
if [[ -n "$HOOK_EVENT" && ("$HOOK_EVENT" == *..* || "$HOOK_EVENT" == */*) ]]; then
	printf 'Error: invalid hook event "%s"\n' "$HOOK_EVENT" >&2
	exit 1
fi
if [[ "$MODULE_NAME" == *..* || "$MODULE_NAME" == */* ]]; then
	printf 'Error: invalid module name "%s"\n' "$MODULE_NAME" >&2
	exit 1
fi

MODULE_PATH="$GIT_HOOKD_DIR/modules/$HOOK_EVENT/$MODULE_NAME.sh"

if [[ -z "$HOOK_EVENT" || ! -f "$MODULE_PATH" ]]; then
	echo "Error: module '$MODULE_SPEC' not found" >&2
	exit 1
fi

# Check if already enabled
LINK_DIR="$GIT_HOOKD_DIR/${HOOK_EVENT}.d"
LINK_NAME="${PRIORITY}-${MODULE_NAME}.sh"

# Check for any existing link to this module (any priority)
if [[ -d "$LINK_DIR" ]]; then
	for existing in "$LINK_DIR"/*-"${MODULE_NAME}.sh"; do
		if [[ -L "$existing" ]]; then
			echo "$MODULE_NAME already enabled ($(basename "$existing"))"
			exit 0
		fi
	done
fi

# Create the .d directory and symlink
mkdir -p "$LINK_DIR"
ln -s "$MODULE_PATH" "$LINK_DIR/$LINK_NAME"
echo "Enabled $MODULE_NAME for $HOOK_EVENT ($LINK_NAME)"
