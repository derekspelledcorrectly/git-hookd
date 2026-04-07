# Security

## Threat Model

git-hookd runs shell scripts automatically during git operations. The primary
threats are:

1. **Arbitrary code execution via `.worktree-init` manifests**: The `[run]`
   section executes shell commands. A malicious manifest in a cloned repo could
   run arbitrary code on checkout.

2. **Path traversal in file operations**: The `[link]` and `[copy]` sections
   resolve relative paths. Crafted entries like `../../.ssh/authorized_keys`
   could read or write outside the worktree.

3. **Environment variable misconfiguration**: `GIT_HOOKD_DIR` controls where
   hooks are installed and where `rm -rf` runs during uninstall. A
   misconfigured or unintentionally exported value could cause hooks to run
   from an unexpected location or delete the wrong directory.

4. **Uninstall safety**: `rm -rf` on a user-controlled path requires validation
   to avoid deleting unrelated directories.

## Mitigations

### `[run]` opt-in gate

The `[run]` section in `.worktree-init` manifests is **blocked by default**.
Commands are displayed but not executed until explicitly allowed via git config:

```bash
# Allow [run] in a specific repo
git config hookd.worktree-init.allow-run true

# Allow [run] globally (use with caution)
git config --global hookd.worktree-init.allow-run true
```

This is inspired by [direnv](https://direnv.net/)'s trust model: you must
explicitly opt in per-repo or globally. Unlike direnv, which re-validates on
file content change, the git config toggle trusts all future manifest edits
once set. Git config's standard precedence
applies (local overrides global).

### Path traversal protection

Both `[link]` and `[copy]` sections validate that resolved paths stay within
their expected directories. Paths containing `..` that would escape the
worktree or main worktree are rejected with a warning. Path resolution uses
`python3 -c "import os; print(os.path.normpath(...))"` for portable
normalization across macOS and Linux (macOS `realpath` lacks the `-m` flag
needed for paths that don't exist yet).

### CLI input validation

- `GIT_HOOKD_DIR` is validated on every CLI invocation and in the installer:
  must be an absolute path, must not contain `..` components, and must not
  point to dangerous locations (`/`, `$HOME`, `/tmp`, `/etc`, `/usr`, `/var`).
  Only these exact root paths are blocked; subdirectories like `/tmp/my-hookd`
  are permitted.
- Remote names in the auto-fetch module are validated against
  `^[a-zA-Z0-9_.-]+$` to prevent shell injection.
- Module skip matching uses `grep -qxF` (fixed strings, full line) to prevent
  regex injection via module names.

### Uninstall safety

Before `rm -rf` on the hookd directory, the uninstall command verifies a `_hookd`
file exists in the target. This prevents accidental deletion if `GIT_HOOKD_DIR`
points somewhere unexpected.

When restoring a previously saved `core.hooksPath`, the saved value is validated:
empty paths and paths that don't start with `/` or `~/` are rejected, and
`core.hooksPath` is unset instead.

## Supply Chain

- CI pins `actions/checkout` to a commit SHA (not a mutable tag).
- The `shfmt` binary downloaded in CI is verified against a SHA256 checksum
  from the official release.

## Reporting Vulnerabilities

If you find a security issue, please email the maintainer directly rather than
opening a public issue. You can find contact information in the git commit
history. Include steps to reproduce and any relevant details about the
environment.
