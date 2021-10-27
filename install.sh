#!/bin/bash

cd ~

# Linking everything
ln -sf $HOME/dotfiles/.zshrc $HOME
ln -sf $HOME/dotfiles/.vimrc $HOME
ln -sf $HOME/dotfiles/.tmux.conf $HOME
ln -sf $HOME/dotfiles/.gitconfig $HOME

# installing
sudo apt-get install -y fzf bat neovim thefuck

# Moving vimrc for nvim
mkdir -p $HOME/.config/nvim
ln -sf  $HOME/dotfiles/init.vim $HOME/.config/nvim/init.vim

# Install oh-my-zsh stuff
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Install pure prompt
mkdir -p "$HOME/.zsh"
git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

source $HOME/.zshrc