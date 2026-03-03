# dot-files

Personal shell/editor/terminal bootstrap for macOS or Linux with Homebrew.

## What this repo contains

- `init.sh`: Bootstrap script that installs Homebrew (if needed), seeds Neovim config, installs packages from `Brewfile`, and sets up Python/Node tooling.
- `symlink-dot-files.sh`: Idempotently creates symlinks from this repo into your home directory and backs up conflicting files.
- `links.manifest`: Declarative source/destination map used by `symlink-dot-files.sh`.
- `verify.sh`: Post-bootstrap checks for tool availability and symlink correctness.
- `tmux.conf`: tmux configuration.
- `zshrc`: zsh configuration
- `Brewfile`: Homebrew package list.
- `scripts/dev.sh`: helper script referenced by `zshrc` (`rundev` alias). Meant to be run immediately after launching your shell.

## Quick start

```bash
git clone <your-repo-url> ~/Repos/dot-files
cd ~/Repos/dot-files
bash init.sh all
```

After setup completes, restart your terminal.

## Notes

- `init.sh` is phase-based and defaults to `all`.
- `init.sh` supports `--dry-run` and `--verbose`.
- `init.sh` expects Homebrew and will attempt to install it if missing.
- `init.sh` clones `https://github.com/bpetersen/kickstart.nvim` into `~/.config/nvim` only when that directory is empty.
- `symlink-dot-files.sh` can be run repeatedly; it skips already-correct links and backs up conflicting paths.

## Re-run safely

You can re-run setup after updating this repo:

```bash
cd ~/Repos/dot-files
bash init.sh all
```

Dry-run before applying changes:

```bash
bash init.sh all --dry-run
```

Run a single phase:

```bash
bash init.sh links
```

Verify current machine state:

```bash
bash verify.sh --verbose
```

## tmux

Reload tmux config without restarting tmux:

```bash
tmux source-file ~/.tmux.conf
```

or inside tmux: `Prefix + r`.
