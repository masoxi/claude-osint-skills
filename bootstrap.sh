#!/usr/bin/env bash
# claude-osint-skills one-line installer for macOS:
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/masoxi/claude-osint-skills/main/bootstrap.sh)"
#
# Installs what is missing (Homebrew, Git, Node.js, uv, Google Chrome, Claude
# Code), clones or updates the repo (default: ~/claude-osint-skills, override with
# CLAUDE_OSINT_DIR) and runs install.sh --guided. Re-run to update.
set -euo pipefail

repo_url="https://github.com/masoxi/claude-osint-skills.git"
dir="${CLAUDE_OSINT_DIR:-$HOME/claude-osint-skills}"
have() { command -v "$1" >/dev/null 2>&1; }

echo "== claude-osint-skills installer =="
[ "$(uname)" = Darwin ] || echo "Not macOS: installing prerequisites is up to you (git, node 18+, uv, claude); continuing."

if [ "$(uname)" = Darwin ]; then
  if ! have brew; then
    echo "Installing Homebrew (asks for your Mac password) ..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  for prefix in /opt/homebrew /usr/local; do
    [ -x "$prefix/bin/brew" ] && eval "$("$prefix/bin/brew" shellenv)"
  done
  pkgs=()
  have git || pkgs+=(git)
  have node || pkgs+=(node)
  have uvx || pkgs+=(uv)
  if [ "${#pkgs[@]}" -gt 0 ]; then
    echo "Installing ${pkgs[*]} ..."
    brew install "${pkgs[@]}"
  fi
  if [ ! -d "/Applications/Google Chrome.app" ] && [ ! -d "$HOME/Applications/Google Chrome.app" ]; then
    echo "Installing Google Chrome ..."
    brew install --cask google-chrome
  fi
fi

if ! have claude; then
  echo "Installing Claude Code ..."
  curl -fsSL https://claude.ai/install.sh | bash
fi
export PATH="$HOME/.local/bin:$PATH"

missing=()
for c in git node npm uvx claude; do have "$c" || missing+=("$c"); done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Still missing: ${missing[*]}. Open a new Terminal window and run the command again." >&2
  exit 1
fi

if [ -d "$dir/.git" ]; then
  echo "Updating $dir ..."
  git -C "$dir" pull --ff-only
else
  echo "Downloading claude-osint-skills to $dir ..."
  git clone "$repo_url" "$dir"
fi

bash "$dir/install.sh" --guided
