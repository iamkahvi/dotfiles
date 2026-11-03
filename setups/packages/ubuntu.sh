#!/usr/bin/env bash
# Ubuntu server packages. CLI only. Called by setups/install.sh. Idempotent.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y fzf bat neovim ripgrep fd-find zsh zoxide tmux git curl python3

# yq (mikefarah). apt has a different yq. scripts/tmux-sessionizer needs this one.
if ! command -v yq >/dev/null 2>&1; then
  arch="$(dpkg --print-architecture)"
  sudo curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" -o /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
fi

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

# TPM for tmux
[ -d "$HOME/.tmux/plugins/tpm" ] ||
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

# yazi, herdr, and pi have no apt package. Report, do not fail.
for tool in yazi herdr pi; do
  command -v "$tool" >/dev/null 2>&1 || echo "$tool is not installed. Install it by hand." >&2
done
