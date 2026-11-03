#!/usr/bin/env bash
# Omarchy (Arch) packages. Called by setups/install.sh. Idempotent.
# setups/omarchy.md has the manual checks for Hyprland, Neovim, and Herdr.
set -euo pipefail

# Zsh and its Arch packages. zsh/.zshrc loads them from /usr/share.
omarchy pkg add zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions fzf
omarchy pkg aur add oh-my-zsh-git zsh-pure-prompt

# Tools
omarchy pkg add ghostty yazi neovim ripgrep fd bat zoxide tmux yq

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
  chsh -s /usr/bin/zsh
fi

if ! command -v herdr >/dev/null 2>&1; then
  echo "herdr is not installed. See https://herdr.dev for the Linux install." >&2
fi
