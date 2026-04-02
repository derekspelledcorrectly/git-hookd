# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

git-hookd is a modular global git hooks framework. It solves the problem that Git's `core.hooksPath` is winner-take-all: setting it to a global directory makes git ignore `.git/hooks/`, breaking tools like pre-commit, husky, and lefthook. git-hookd installs a single dispatcher that runs modular hook scripts from `.d/` directories, then chains to local repo hooks.

## Commands

```bash
make test          # Run all bats tests
make lint          # shellcheck -x + shfmt validation
make fmt           # Auto-format with shfmt
make check         # lint + test

# Single test file
bats tests/modules/worktree-init.bats

# Single test by name
bats -f "symlinks listed files" tests/modules/worktree-init.bats
```

Pre-commit hooks run shellcheck, shfmt, and bats automatically on commit.

## Architecture

**Dispatcher** (`libexec/git-hookd/_hookd`): All hook names (post-checkout, pre-commit, etc.) are symlinks to this single file. It determines the hook type from `basename "$0"`, runs modules from `<HOOKD_DIR>/<hook>.d/` in lexicographic order, then chains to the local `.git/hooks/<hook>`. Pre-hooks (`pre-*`, `prepare-commit-msg`, `commit-msg`, `update`) use fail-fast semantics; post-hooks use run-all. Modules listed in `hookd.skip` git config are silently skipped (supports per-repo overrides).

**CLI** (`bin/git-hookd`): Resolves project root, then sources the appropriate subcommand from `libexec/git-hookd/cli/`. Each subcommand is a standalone script. `GIT_HOOKD_DIR` (default `~/.local/share/git-hookd`) is where hooks get installed.

**Modules** (`modules/<hook-type>/<name>.sh`): Self-contained scripts that receive the same arguments git passes to the hook. Enabled by symlinking into `<hook>.d/` with a numeric priority prefix (e.g., `50-worktree-init.sh`).

**Completions** (`completions/`): Three files. `git-hookd.bash` for bash-completion, `_git-hookd` for zsh native completion, and `_git_hookd` for Homebrew's git-completion.bash wrapper. The underscore variant uses `#autoload` and `__gitcomp` so `git hookd <TAB>` works when Homebrew provides the zsh git completion. Installed via `git hookd completions --install`.

**Installer** (`install.sh`): Curl-pipe-bash installer with interactive chezmoi auto-detection. Reads from `/dev/tty` for interactive prompts to work under piped input.

## Module Conventions

- `set -euo pipefail` at top
- Prefix output with `[module-name]`
- Exit non-zero to signal failure (blocks pre-hooks, logged for post-hooks)
- Numeric prefix controls execution order (lower = earlier)

## Testing Patterns

Tests use bats-core with bats-support and bats-assert (vendored as git submodules in `tests/test_helper/`).

Standard test setup:
```bash
load ../test_helper
setup() {
    setup_temp_dir                    # creates $BATS_TEST_TMPDIR
    setup_hookd                       # minimal hookd install, exports $GIT_HOOKD_DIR
    REPO_DIR=$(setup_test_repo)       # git repo with initial commit
    git -C "$REPO_DIR" config core.hooksPath "$GIT_HOOKD_DIR"
}
teardown() {
    cd /
    teardown_temp_dir
}
```

Module tests enable modules by symlinking directly from `$PROJECT_ROOT/modules/` into the test hookd's `.d/` directory, then trigger real git operations to exercise the full dispatcher-to-module path.

## Shell Formatting

shfmt flags: `-i 0 -ci` (tab indentation, switch case indent). This is enforced by pre-commit and `make lint`.

## Key Gotchas

- Dispatcher uses `dirname "$0"` (not realpath) to find `.d/` dirs, because `$0` is the hook symlink and we need that directory to locate modules.
- Local hook chaining uses `git rev-parse --git-common-dir` to support worktrees.
- `core.hooksPath` is stored with `~` prefix for portability.
- In-place installs (chezmoi externals, where `GIT_HOOKD_ROOT == GIT_HOOKD_DIR`) symlink the dispatcher instead of copying, and skip module copying.
- After changing CLI scripts, modules, or the dispatcher, run `./bin/git-hookd install --force` to copy updates to the install dir. The installed copy at `~/.local/share/git-hookd/` is independent of the repo.
- Interactive prompts must use `/dev/tty` for both input and output (for curl-pipe-bash compatibility). Probe with `printf '' >/dev/tty 2>/dev/null` before attempting; `-e /dev/tty` is true in bats/CI even when the device is not usable.
