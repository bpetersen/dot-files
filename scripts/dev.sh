#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

repo_dir="$HOME/Repos"
if [ -n "${1:-}" ]; then
  repo_dir="$repo_dir/$1"
fi

if [ ! -d "$repo_dir" ]; then
  echo "Repository directory not found: $repo_dir"
  exit 1
fi

if ! tmux has-session -t dev 2>/dev/null; then
  cd "$repo_dir"
  tmux new-session -s dev -n editor -d
  tmux split-window -h -p 40 -t dev
  tmux split-window -v -p 40 -t dev
  tmux new-window -n console -t dev
  tmux send-keys -t dev:2 'cd ~' C-m
  tmux select-window -t dev:1
fi

tmux attach -t dev
