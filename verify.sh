#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/links.manifest"
VERBOSE=0
FAILURES=0

pass() { printf 'PASS: %s\n' "$1"; }
warn() { printf 'WARN: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg"
      exit 1
      ;;
  esac
done

if [ ! -f "$MANIFEST_FILE" ]; then
  fail "Missing links manifest: $MANIFEST_FILE"
else
  while IFS='|' read -r src_rel dest_tpl; do
    [ -z "${src_rel// /}" ] && continue
    [ "${src_rel#\#}" != "$src_rel" ] && continue

    src="$SCRIPT_DIR/$src_rel"
    dest="${dest_tpl//\$HOME/$HOME}"

    if [ ! -e "$src" ]; then
      fail "Source missing for manifest entry: $src"
      continue
    fi

    if [ ! -L "$dest" ]; then
      fail "Not a symlink: $dest"
      continue
    fi

    target="$(readlink "$dest")"
    if [ "$target" = "$src" ]; then
      pass "Symlink OK: $dest"
    else
      fail "Symlink target mismatch: $dest -> $target (expected $src)"
    fi
  done < "$MANIFEST_FILE"
fi

if command -v brew >/dev/null 2>&1; then
  if brew bundle check --file "$SCRIPT_DIR/Brewfile" >/dev/null 2>&1; then
    pass "Brew bundle check passed"
  else
    warn "brew bundle check reported missing items"
  fi
else
  warn "brew not found"
fi

for cmd in git tmux nvim python3 node npm; do
  if command -v "$cmd" >/dev/null 2>&1; then
    if [ "$VERBOSE" -eq 1 ]; then
      version="$($cmd --version 2>/dev/null | head -n 1 || true)"
      pass "$cmd found (${version:-version unavailable})"
    else
      pass "$cmd found"
    fi
  else
    warn "$cmd not found"
  fi
done

if [ -d "$HOME/.config/nvim/.git" ]; then
  pass "Neovim config repo exists at ~/.config/nvim"
else
  warn "Neovim config repo missing at ~/.config/nvim"
fi

if [ "$FAILURES" -gt 0 ]; then
  printf '\nVerification completed with %s failure(s).\n' "$FAILURES"
  exit 1
fi

printf '\nVerification completed with no hard failures.\n'
