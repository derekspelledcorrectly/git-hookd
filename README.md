# git-hookd

A lightweight, modular global git hooks framework.

## Why?

Git only supports **one hooks directory** per repo. By default that's `.git/hooks/`. If you set `core.hooksPath` globally to get hooks on every repo, Git stops looking at `.git/hooks/` entirely. It's winner-take-all.

This creates a conflict the moment you want both global hooks and per-repo hooks:

- You use **[pre-commit](https://pre-commit.com)** for per-repo linting and formatting. You also want a global pre-commit hook that prevents commits to `main`. Setting `core.hooksPath` globally breaks pre-commit's `.git/hooks/pre-commit`.

- You use **husky** in a JS project to run tests on commit. Your org also requires global hooks for security scanning. Same conflict: one wins, the other is ignored.

- You use **lefthook** in some repos but want global post-checkout hooks for worktree setup across all repos. You can't have both.

There's no built-in way to compose hooks from multiple sources. git-hookd fixes this.

## How It Works

git-hookd installs a single dispatcher script into your global `core.hooksPath`. All hook names (pre-commit, post-checkout, etc.) are symlinks to this dispatcher.

When Git triggers a hook, the dispatcher does two things:

1. Runs all module scripts in `<hook-name>.d/` in lexicographic order
2. Chains to the local repo hook at `.git/hooks/<hook-name>`

Your pre-commit framework, husky setup, or any local hooks keep working exactly as before. Global and local hooks coexist.

### Hook semantics

- **Pre-hooks** (pre-commit, pre-push, etc.): fail-fast. First module failure blocks the git operation.
- **Post-hooks** (post-checkout, post-commit, etc.): run-all. Every module runs regardless of earlier failures. Always chains to local hooks.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/derekspelledcorrectly/git-hookd/main/install.sh | bash

# Enable modules
git hookd enable protect-branch
git hookd enable worktree-init

# See what's available
git hookd list
```

## Installation

### curl | bash

```bash
curl -fsSL https://raw.githubusercontent.com/derekspelledcorrectly/git-hookd/main/install.sh | bash
```

### Manual (git clone)

```bash
git clone https://github.com/derekspelledcorrectly/git-hookd.git ~/.local/share/git-hookd
export PATH="$HOME/.local/bin:$PATH"
ln -s ~/.local/share/git-hookd/bin/git-hookd ~/.local/bin/git-hookd
git hookd install
```

### chezmoi

The installer auto-detects chezmoi. Just run the curl|bash command above and
choose the chezmoi option when prompted. It will:

1. Add a `.chezmoiexternal.toml` entry to pull git-hookd on `chezmoi apply`
2. Create a `run_onchange` script that creates the CLI symlink and runs
   `git hookd install` on apply

New machines get git-hookd automatically when you `chezmoi apply`.

<details>
<summary>Manual chezmoi setup</summary>

If you prefer to set it up yourself, add to your `.chezmoiexternal.toml`:

```toml
[".local/share/git-hookd"]
    type = "git-repo"
    url = "https://github.com/derekspelledcorrectly/git-hookd.git"
    refreshPeriod = "168h"
```

Add a `run_onchange_install-git-hookd.sh.tmpl` script that creates the
`~/.local/bin/git-hookd` symlink and calls `git hookd install` to set up
the dispatcher and `core.hooksPath`. Use a chezmoi template hash to
trigger on changes:
```
# {{ $hookd := joinPath .chezmoi.homeDir ".local/share/git-hookd/libexec/git-hookd/_hookd" -}}
# hash: {{ if stat $hookd }}{{ include $hookd | sha256sum }}{{ else }}not-yet-installed{{ end }}
```

</details>

### Custom install location

Set `GIT_HOOKD_DIR` to override the default `~/.local/share/git-hookd/`:

```bash
GIT_HOOKD_DIR=~/my/custom/path git hookd install
```

## CLI Reference

| Command | Description |
|---------|-------------|
| `git hookd install` | Set up hooks directory and `core.hooksPath` |
| `git hookd install --force` | Override existing `core.hooksPath` |
| `git hookd install --dry-run` | Show what would be done |
| `git hookd uninstall` | Remove hooks and restore previous config |
| `git hookd enable <module>` | Enable a module (symlink into `.d/` dir) |
| `git hookd enable --priority N <module>` | Enable with custom sort priority (default: 50) |
| `git hookd disable <module>` | Disable a module (remove symlink) |
| `git hookd list` | Show available modules and their status |
| `git hookd status` | Show installation status |

## Bundled Modules

### protect-branch

Prevents accidental commits to protected branches. Blocks commits to `main` and `master` by default.

```
$ git checkout main && git commit -m "oops"
[protect-branch] Commit blocked: 'main' is a protected branch.
[protect-branch] To override: HOOKD_ALLOW_PROTECTED=1 git commit ...
```

Configure custom patterns via git config:

```bash
git config --global hookd.protect-branch.pattern "release/*"
git config --global --add hookd.protect-branch.pattern "production"
```

Setting any patterns replaces the defaults. Override when you need to:

```bash
HOOKD_ALLOW_PROTECTED=1 git commit -m "hotfix: emergency fix on main"
```

### worktree-init

Automatically sets up new git worktrees from a `.worktree-init` manifest in the main worktree. Supports three section types:

```ini
[link]
# Symlink these files from main worktree (shared, changes reflect immediately)
.env
config/secrets.yml

[copy]
# Copy these files (independent copy per worktree)
.vscode/settings.json

[run]
# Run these commands in the new worktree
npm install
```

Sections execute in fixed order: link, copy, run (regardless of order in the file).

### auto-fetch

Background fetch after branch switch. Keeps remote-tracking refs fresh so you see divergence early without remembering to fetch manually.

```
$ git checkout feature/new-thing
[auto-fetch] Fetching from origin in background
```

The fetch runs in the background and won't slow down your checkout. A configurable cooldown (default: 60s) prevents fetch spam when switching branches rapidly.

```bash
# Set cooldown to 5 minutes
git config --global hookd.auto-fetch.cooldown 300

# Fetch from a different remote
git config --global hookd.auto-fetch.remote upstream
```

### Enabling modules

No modules are enabled by default. Enable the ones you want:

```bash
git hookd enable protect-branch
git hookd enable worktree-init
git hookd enable auto-fetch
```

## Writing Your Own Modules

A module is just an executable shell script placed in the right directory:

```
~/.local/share/git-hookd/modules/<hook-event>/<module-name>.sh
```

Example: a pre-commit module that checks for debug statements:

```bash
#!/usr/bin/env bash
# modules/pre-commit/no-debug.sh
set -euo pipefail

if git diff --cached --name-only | xargs grep -l 'debugger\|console\.log\|binding\.pry' 2>/dev/null; then
    echo "[no-debug] Found debug statements in staged files" >&2
    exit 1
fi
```

Then enable it:
```bash
git hookd enable no-debug
```

### Module conventions

- Use `set -euo pipefail` at the top
- Print messages prefixed with `[module-name]` for clarity
- Exit non-zero to signal failure
- Modules receive the same arguments git passes to the hook
- Use numeric prefixes to control execution order: `10-first.sh` runs before `50-second.sh`

## How Modules Are Managed

The directory structure IS the configuration:

```
~/.local/share/git-hookd/
  _hookd                          # dispatcher (all hooks symlink here)
  post-checkout -> _hookd
  pre-commit -> _hookd
  ...
  post-checkout.d/                # enabled modules for post-checkout
    50-worktree-init.sh -> ../modules/post-checkout/worktree-init.sh
  modules/                        # module library
    post-checkout/
      worktree-init.sh
```

- **Enable** = create a symlink in the `.d/` directory
- **Disable** = remove the symlink
- No config files, no database, no daemon

## Development

```bash
# Run tests
make test

# Lint (shellcheck + shfmt)
make lint

# Auto-format
make fmt

# Both
make check
```

Tests use [bats-core](https://bats-core.readthedocs.io/) with bats-support and bats-assert (vendored as submodules).

## License

MIT
