#!/usr/bin/env bash
# git-hookd list subcommand

if [[ ! -d "$GIT_HOOKD_DIR/modules" ]]; then
	echo "No modules found. Run 'git hookd install' first." >&2
	exit 1
fi

for hook_dir in "$GIT_HOOKD_DIR"/modules/*/; do
	[[ -d "$hook_dir" ]] || continue
	hook_event="$(basename "$hook_dir")"
	echo "$hook_event:"

	for module_file in "$hook_dir"/*.sh; do
		[[ -f "$module_file" ]] || continue
		module_name="$(basename "$module_file" .sh)"

		# Check if enabled (any priority)
		state="disabled"
		d_dir="$GIT_HOOKD_DIR/${hook_event}.d"
		if [[ -d "$d_dir" ]]; then
			for link in "$d_dir"/*-"${module_name}.sh"; do
				if [[ -L "$link" ]]; then
					state="enabled"
					break
				fi
			done
		fi

		echo "  $module_name  [$state]"
	done
	echo
done
