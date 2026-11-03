#!/usr/bin/env bash
# macOS packages. Called by setups/install.sh. Idempotent.
set -euo pipefail

# Xcode CLI tools
xcode-select --install 2>/dev/null || true

# Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Core tools
brew install curl wget git zsh neovim bat fzf ripgrep fd tree zoxide yazi yq tmux herdr

# Languages
brew install node nvm go python3 rustup-init
brew install chruby ruby-build

# Apps
brew install --cask ghostty hammerspoon visual-studio-code

# Oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh plugins. zsh/.zshrc loads them from $ZSH_CUSTOM/plugins.
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] ||
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] ||
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Pure prompt. zsh/.zshrc loads it from ~/.zsh/pure.
mkdir -p "$HOME/.zsh"
[ -d "$HOME/.zsh/pure" ] || git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

# fzf key bindings (~/.fzf.zsh)
[ -f "$HOME/.fzf.zsh" ] || "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc --no-bash --no-fish

# TPM for tmux
[ -d "$HOME/.tmux/plugins/tpm" ] ||
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
