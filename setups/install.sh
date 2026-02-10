#!/bin/bash
set -euo pipefail

cd ~

DOTFILES="$HOME/dotfiles"

# Core tools
sudo apt-get update
sudo apt-get install -y fzf bat neovim ripgrep fd-find zsh zoxide

# Symlink configs
ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES/vim/.vimrc" "$HOME/.vimrc"
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

# Neovim config
mkdir -p "$HOME/.config/nvim"
ln -sf "$DOTFILES/vim/init.lua" "$HOME/.config/nvim/init.lua"

# Oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Zsh plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || \
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || \
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

# Pure prompt
mkdir -p "$HOME/.zsh"
[ -d "$HOME/.zsh/pure" ] || git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

# TPM for tmux
[ -d "$HOME/.tmux/plugins/tpm" ] || \
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

echo "Done. Open a new shell or run: source ~/.zshrc"
