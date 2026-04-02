# bash completion for git-hookd
# Install: git hookd completions --install bash
# Or source this file directly in ~/.bashrc

_git_hookd_modules_available() {
	local hookd_dir="${GIT_HOOKD_DIR:-$HOME/.local/share/git-hookd}"
	if [[ ! -d "$hookd_dir/modules" ]]; then
		return
	fi
	local hook_dir module_file hook_event module_name
	for hook_dir in "$hookd_dir"/modules/*/; do
		[[ -d "$hook_dir" ]] || continue
		hook_event="$(basename "$hook_dir")"
		for module_file in "$hook_dir"/*.sh; do
			[[ -f "$module_file" ]] || continue
			module_name="$(basename "$module_file" .sh)"
			printf '%s/%s\n' "$hook_event" "$module_name"
		done
	done
}

_git_hookd_modules_enabled() {
	local hookd_dir="${GIT_HOOKD_DIR:-$HOME/.local/share/git-hookd}"
	local d_dir link hook_event module_name
	for d_dir in "$hookd_dir"/*.d; do
		[[ -d "$d_dir" ]] || continue
		hook_event="$(basename "$d_dir" .d)"
		for link in "$d_dir"/*; do
			[[ -L "$link" ]] || continue
			module_name="$(basename "$link")"
			# Strip priority prefix (e.g., 50-) and .sh suffix
			module_name="${module_name#*-}"
			module_name="${module_name%.sh}"
			printf '%s/%s\n' "$hook_event" "$module_name"
		done
	done
}

_git_hookd() {
	local cur words cword
	_init_completion || return

	local commands="install uninstall enable disable list status completions"

	if ((cword == 1)); then
		mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
		return
	fi

	local cmd="${words[1]}"
	case "$cmd" in
		install)
			mapfile -t COMPREPLY < <(compgen -W "--force --dry-run" -- "$cur")
			;;
		enable)
			if [[ "$cur" == -* ]]; then
				mapfile -t COMPREPLY < <(compgen -W "--priority" -- "$cur")
			else
				local modules
				modules="$(_git_hookd_modules_available)"
				mapfile -t COMPREPLY < <(compgen -W "$modules" -- "$cur")
			fi
			;;
		disable)
			local modules
			modules="$(_git_hookd_modules_enabled)"
			mapfile -t COMPREPLY < <(compgen -W "$modules" -- "$cur")
			;;
		completions)
			mapfile -t COMPREPLY < <(compgen -W "--install bash zsh" -- "$cur")
			;;
	esac
}

# Register for standalone git-hookd
complete -F _git_hookd git-hookd
