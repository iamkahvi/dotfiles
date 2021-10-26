export DF_HOME=~/dotfiles

# Linking everything
ln -sf $DF_HOME/.zshrc ~/.zshrc 
ln -sf $DF_HOME/.vimrc ~/.vimrc 
ln -sf $DF_HOME/.tmux.conf ~/.tmux.conf
ln -sf $DF_HOME/.gitconfig ~/.gitconfig

# installing
sudo apt-get install -y fzf bat neovim thefuck

# Moving vimrc for nvim
mkdir -p .config/nvim
ln -sf  $DF_HOME/init.vim .config/nvim/init.vim

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
