#!/bin/bash
set -euo pipefail

# Starting from scratch on macOS

cd ~

# Xcode CLI tools
xcode-select --install 2>/dev/null || true

# Homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Core tools
brew install curl wget git zsh neovim bat fzf ripgrep fd tree zoxide

# Languages
brew install node nvm go python3 rustup-init
brew install chruby ruby-build

# Apps
brew install --cask ghostty hammerspoon visual-studio-code

# Clone dotfiles
DOTFILES="$HOME/dotfiles"
if [ ! -d "$DOTFILES" ]; then
  git clone https://github.com/iamkahvi/dotfiles "$DOTFILES"
fi

# Symlink configs
ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES/vim/.vimrc" "$HOME/.vimrc"
ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

# Neovim config
mkdir -p "$HOME/.config/nvim"
ln -sf "$DOTFILES/vim/init.lua" "$HOME/.config/nvim/init.lua"

# Hammerspoon config
mkdir -p "$HOME/.hammerspoon"
ln -sf "$DOTFILES/hammerspoon/init.lua" "$HOME/.hammerspoon/init.lua"

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
if [ "$(uname -p)" = "arm" ]; then
  # Installed via homebrew on Apple Silicon
  :
else
  mkdir -p "$HOME/.zsh"
  [ -d "$HOME/.zsh/pure" ] || git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
fi

# TPM for tmux
[ -d "$HOME/.tmux/plugins/tpm" ] || \
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"

echo "Done. Open a new shell or run: source ~/.zshrc"
