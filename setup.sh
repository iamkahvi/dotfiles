#!bin/bash

# starting from scratch on MacOS

cd ~
sudo xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install curl wget git zsh vim tree fzf ack 

brew install python python@2

brew install chruby ruby-build
gem install bundler

brew install rustup

pip install --upgrade setuptools
pip install --upgrade pip

brew install node nvm

brew install go gvm

brew install --cask hammerspoon visual-studio-code iterm2

sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/iamkahvi/dotfiles
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

ln dotfiles/.zshrc dotfiles/.vimrc dotfiles/init.lua dotfiles/.tmux.conf .

source ~/.zshrc