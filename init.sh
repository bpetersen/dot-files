#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_NAME="$(uname -s)"
DRY_RUN=0
VERBOSE=0
PHASE="all"

# shellcheck disable=SC2059
log() { printf "${CYAN}%s${NC}\n" "$1"; }
# shellcheck disable=SC2059
ok() { printf "${GREEN}%s${NC}\n" "$1"; }
# shellcheck disable=SC2059
warn() { printf "${RED}%s${NC}\n" "$1"; }

usage() {
  cat <<'USAGE'
Usage: bash init.sh [phase] [--dry-run] [--verbose]

Phases:
  core      Preflight checks, config dirs, and kickstart.nvim clone
  links     Symlink dotfiles using links.manifest
  tools     Homebrew + Brewfile + Python/Node tooling
  shell     Final shell reminders
  verify    Validate installed tools and symlinks
  all       Run all phases in order (default)

Flags:
  --dry-run Print planned actions without making changes
  --verbose Print additional command details
USAGE
}

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

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  local cmd="$1"
  if ! have_cmd "$cmd"; then
    warn "Required command not found: $cmd"
    exit 1
  fi
}

load_brew_env() {
  if have_cmd brew; then
    return
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

ensure_brew() {
  if have_cmd brew; then
    return
  fi

  log "Homebrew not found. Installing..."
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n'
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  load_brew_env

  if ! have_cmd brew; then
    warn "Homebrew is unavailable after install attempt. Exiting."
    exit 1
  fi
}

phase_core() {
  log "Running core phase..."

  require_cmd curl
  require_cmd git

  if [ ! -w "$HOME" ]; then
    warn "Home directory is not writable in this shell: $HOME"
  fi

  run mkdir -p "$HOME/.config" "$HOME/.config/nvim" "$HOME/.config/prettier"

  if [ -d "$HOME/.config/nvim/.git" ]; then
    log "Neovim repo already exists at ~/.config/nvim; ensuring develop branch."
    run git -C "$HOME/.config/nvim" fetch origin develop
    run git -C "$HOME/.config/nvim" checkout develop
  elif [ -z "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    log "Cloning kickstart.nvim (develop) into ~/.config/nvim"
    run git clone --branch develop --single-branch git@github.com:bpetersen/kickstart.nvim.git "$HOME/.config/nvim"
  else
    warn "~/.config/nvim exists and is non-empty; skipping kickstart.nvim clone."
  fi
}

phase_links() {
  log "Running links phase..."
  if [ "$DRY_RUN" -eq 1 ] && [ "$VERBOSE" -eq 1 ]; then
    run "$SCRIPT_DIR/symlink-dot-files.sh" --dry-run --verbose
  elif [ "$DRY_RUN" -eq 1 ]; then
    run "$SCRIPT_DIR/symlink-dot-files.sh" --dry-run
  elif [ "$VERBOSE" -eq 1 ]; then
    run "$SCRIPT_DIR/symlink-dot-files.sh" --verbose
  else
    run "$SCRIPT_DIR/symlink-dot-files.sh"
  fi
}

phase_tools() {
  log "Running tools phase..."

  require_cmd curl
  ensure_brew
  load_brew_env

  run brew upgrade
  run brew bundle --file "$SCRIPT_DIR/Brewfile"
  run brew cleanup

  if have_cmd python3; then
    log "Installing Python user package: pynvim"
    if run python3 -m pip install --user --upgrade pynvim; then
      :
    else
      warn "Retrying pynvim install with --break-system-packages"
      run python3 -m pip install --user --upgrade --break-system-packages pynvim
    fi
  else
    warn "python3 not found; skipping pynvim install."
  fi

  if [ "$DRY_RUN" -ne 1 ]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s /opt/homebrew/opt/nvm/nvm.sh ]; then
      # shellcheck disable=SC1091
      . /opt/homebrew/opt/nvm/nvm.sh
    elif [ -s "$HOME/.nvm/nvm.sh" ]; then
      # shellcheck disable=SC1090
      . "$HOME/.nvm/nvm.sh"
    fi
  fi

  if have_cmd nvm; then
    log "Installing Node.js using nvm"
    run nvm install node
  elif ! have_cmd node; then
    log "nvm not found; installing Node.js with Homebrew"
    run brew install node
  fi

  if have_cmd npm; then
    log "Installing global npm packages"
    run npm install -g eslint eslint-plugin-react prettier neovim
  else
    warn "npm not found; skipping global npm package installs."
  fi
}

phase_shell() {
  log "Running shell phase..."
  log "Don't forget to install a nerd font."
  ok "Close your terminal and reopen."
}

phase_verify() {
  log "Running verify phase..."
  if [ "$VERBOSE" -eq 1 ]; then
    run "$SCRIPT_DIR/verify.sh" --verbose
  else
    run "$SCRIPT_DIR/verify.sh"
  fi
}

run_phase() {
  case "$1" in
    core) phase_core ;;
    links) phase_links ;;
    tools) phase_tools ;;
    shell) phase_shell ;;
    verify) phase_verify ;;
    all)
      phase_core
      phase_links
      phase_tools
      phase_shell
      phase_verify
      ;;
    *)
      warn "Unknown phase: $1"
      usage
      exit 1
      ;;
  esac
}

for arg in "$@"; do
  case "$arg" in
    core|links|tools|shell|verify|all) PHASE="$arg" ;;
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      warn "Unknown argument: $arg"
      usage
      exit 1
      ;;
  esac
done

run_phase "$PHASE"
