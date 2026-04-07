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

3. **Environment variable poisoning**: `GIT_HOOKD_DIR` controls where hooks
   are installed. A malicious value could redirect to attacker-controlled scripts.

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

This follows the same trust model as [direnv](https://direnv.net/): you must
explicitly opt in per-repo or globally. Git config's standard precedence
applies (local overrides global).

### Path traversal protection

Both `[link]` and `[copy]` sections validate that resolved paths stay within
their expected directories. Paths containing `..` that would escape the
worktree or main worktree are rejected with a warning. Path resolution uses
`python3 -c "import os; print(os.path.normpath(...))"` for portable
normalization across macOS and Linux.

### CLI input validation

- `GIT_HOOKD_DIR` is validated on every CLI invocation: must be an absolute
  path and must not point to dangerous locations (`/`, `$HOME`, `/tmp`, `/etc`,
  `/usr`, `/var`).
- Remote names in the auto-fetch module are validated against
  `^[a-zA-Z0-9_.-]+$` to prevent shell injection.
- Module skip matching uses `grep -qxF` (fixed strings, full line) to prevent
  regex injection via module names.

### Uninstall safety

Before `rm -rf` on the hookd directory, the uninstall command verifies a `_hookd`
file exists in the target. This prevents accidental deletion if `GIT_HOOKD_DIR`
points somewhere unexpected.

When restoring a previously saved `core.hooksPath`, the saved value is validated:
empty or relative paths are rejected and `core.hooksPath` is unset instead.

## Supply Chain

- CI pins `actions/checkout` to a commit SHA (not a mutable tag).
- The `shfmt` binary downloaded in CI is verified against a SHA256 checksum
  from the official release.

## Reporting Vulnerabilities

If you find a security issue, please email the maintainer directly rather than
opening a public issue. You can find contact information in the git commit
history. Include steps to reproduce and any relevant details about the
environment.
