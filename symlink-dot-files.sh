#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_FILE="$SCRIPT_DIR/links.manifest"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
VERBOSE=0

run() {
  local cmd=("$@")

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] '
    printf '%q ' "${cmd[@]}"
    printf '\n'
    return 0
  fi

  if [ "$VERBOSE" -eq 1 ]; then
    printf '[run] '
    printf '%q ' "${cmd[@]}"
    printf '\n'
  fi

  "${cmd[@]}"
}

link_file() {
  local src="$1"
  local dest="$2"
  local backup
  local current_target

  if [ ! -e "$src" ]; then
    printf 'Skipping missing source: %s\n' "$src"
    return 0
  fi

  run mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ]; then
    current_target="$(readlink "$dest")"
    if [ "$current_target" = "$src" ]; then
      printf 'Already linked: %s -> %s\n' "$dest" "$src"
      return 0
    fi
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="${dest}.backup-${BACKUP_SUFFIX}"
    run mv "$dest" "$backup"
    printf 'Backed up existing path: %s -> %s\n' "$dest" "$backup"
  fi

  run ln -s "$src" "$dest"
  printf 'Linked: %s -> %s\n' "$dest" "$src"
}

if [ ! -f "$MANIFEST_FILE" ]; then
  printf 'Manifest file not found: %s\n' "$MANIFEST_FILE"
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    *)
      printf 'Unknown argument: %s\n' "$arg"
      exit 1
      ;;
  esac
done

while IFS='|' read -r src_rel dest_tpl; do
  [ -z "${src_rel// /}" ] && continue
  [ "${src_rel#\#}" != "$src_rel" ] && continue

  src="$SCRIPT_DIR/$src_rel"
  dest="${dest_tpl//\$HOME/$HOME}"

  link_file "$src" "$dest"
done < "$MANIFEST_FILE"
