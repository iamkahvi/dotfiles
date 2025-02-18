#!bin/bash

# starting from scratch on MacOS

cd ~
sudo xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install curl wget git zsh vim tree fzf ack neovim bat

brew install python python@2

brew install chruby ruby-build
gem install bundler

brew install rustup

pip install --upgrade setuptools pip

brew install node nvm go gvm fd

brew install --cask hammerspoon visual-studio-code iterm2

cd ~
git clone https://github.com/iamkahvi/dotfiles $HOME

# Linking everything
ln -sf $HOME/dotfiles/.zshrc $HOME
ln -sf $HOME/dotfiles/.vimrc $HOME
ln -sf $HOME/dotfiles/.tmux.conf $HOME
ln -sf $HOME/dotfiles/.gitconfig $HOME
ln -sf $HOME/dotfiles/init.lua $HOME

# Moving vimrc for nvim
mkdir -p $HOME/.config/nvim
ln -sf  $HOME/dotfiles/init.vim $HOME/.config/nvim/

# Install oh-my-zsh stuff
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Install nvim plugin manager
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \ 
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Install pure prompt
mkdir -p ".zsh"
git clone https://github.com/sindresorhus/pure.git ".zsh/pure"

source $HOME/.zshrc
