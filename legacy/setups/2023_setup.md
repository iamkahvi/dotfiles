2023 macOS setup
========================

This is my note.

I want to record the setup of this macbook.  My first approach is to record my command history and edit it down.

    1  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   16  (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.zprofile
   17  eval "$(/opt/homebrew/bin/brew shellenv)"
   20  brew install --cask iterm2
   28  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
   30  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
   31  brew install --cask sublime-text
   32  brew install neovim
   35  brew install --cask sublime-text
   36  brew install --cask visual-studio-code
   38  brew install python
   39  brew install rustup
   40  brew install node
   46  brew install go
   48  git clone git@github.com:iamkahvi/dotfiles.git
   49  ssh-keygen -t ed25519 -C "iamkahvi@gmail.com"
   58  mv github github.pub .ssh
   60  eval "$(ssh-agent -s)"
   61  open ~/.ssh/config
   62  nvim ~/.ssh/config
   63  ssh-add --apple-use-keychain ~/.ssh/github
   64  pbcopy < .ssh/github.pub
   71  mkdir Developer
   85  sudo rm -rf Movies Music
   86  sudo rm -rf Pictures
   89  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"\n\n
   90  brew install broot
  101  brew install pure
  107  ln .vimrc .oh-my-zsh .tmux.conf .
  114  brew install fzf
  131  ln -f ./dotfiles/settings.json ./Library/Application\ Support/Code/User/settings.json
  133  ln -f ./dotfiles/keybindings.json ./Library/Application\ Support/Code/User/keybindings.json
  136  ln -f ./dotfiles/init.lua ./.hammerspoon/
  142  mkdir notes
  144  brew install deno
  145  curl -fsSL https://bun.sh/install | bash
  154  npm install --global yarn
