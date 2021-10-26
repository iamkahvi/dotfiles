#!bin/bash

# starting from scratch on MacOS

cd ~
sudo xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install curl wget git zsh vim tree fzf ack neovim

brew install python python@2

brew install chruby ruby-build
gem install bundler

brew install rustup

pip install --upgrade setuptools pip

brew install node nvm go gvm

brew install --cask hammerspoon visual-studio-code iterm2

export DF_HOME=~/dotfiles
git clone https://github.com/iamkahvi/dotfiles $DF_HOME

# Linking everything
ln -sf $DF_HOME/.zshrc ~/.zshrc 
ln -sf $DF_HOME/.vimrc ~/.vimrc 
ln -sf $DF_HOME/.tmux.conf ~/.tmux.conf
ln -sf $DF_HOME/.gitconfig ~/.gitconfig
ln -sf $DF_HOME/init.lua ~/init.lua

# Install oh-my-zsh stuff
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Install nvim plugin manager
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \ 
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Install pure prompt
mkdir -p "$HOME/.zsh"
git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

source ~/.zshrc