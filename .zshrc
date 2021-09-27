# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Adding ANTLR
export ANTLR_PATH=$HOME/antlr.jar
export PATH=$PATH:$ANTLR_PATH 
export CLASSPATH=$PATH

# Adding Julia
export PATH=$PATH:/Applications/Julia-1.5.app/Contents/Resources/julia/bin

export PATH=/usr/local/smlnj/bin:"$PATH"

# Adding NVM
export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Adding Maven
export PATH=$PATH:/opt/apache-maven-3.6.3/bin

# Adding VSCode
export PATH=$PATH:/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin

# Adding Go
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

alias showp='echo $PATH | tr -s ":" "\n"'
alias configz='vim ~/.zshrc'
alias configv='vim ~/.vimrc'
alias dev='cd /Users/Kahvi/Documents/dev'
alias icloud='fds ~/Library/Mobile\ Documents/com\~apple\~CloudDocs'
alias smlr='socat READLINE EXEC:sml'
alias cppcompile='c++ -std=c++11 -stdlib=libc++'


eval $( gdircolors -b $HOME/LS_COLORS )

# User Configuration

# Setting up history backup
HISTSIZE=500000
SAVEHIST=500000
setopt appendhistory
setopt INC_APPEND_HISTORY  
setopt SHARE_HISTORY

# Enable extended file globs
setopt extendedglob

setopt auto_cd
setopt no_beep
setopt correct

ZSH_THEME=sammy

plugins=(git colored-man colorize pip python zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

unalias pip

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# ssh
export SSH_KEY_PATH="~/.ssh/rsa_id"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fds - cd to selected directory
fds() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
				  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}

ff() {
  local file
  file=$(find ${1:-.} -path '*/\.*' -prune \
                                  -o -type f -print 2> /dev/null | fzf --preview 'bat -p --color always {}' +m) &&
  vim "$file"
}

# fh - search in your command history and execute selected command
fh() {
  eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

### Added by Zplugin's installer
source $HOME/.zplugin/bin/zplugin.zsh
autoload -Uz _zplugin
(( ${+_comps} )) && _comps[zplugin]=_zplugin
### End of Zplugin's installer chunk
alias config='/usr/bin/git --git-dir=/Users/Kahvi/.cfg/ --work-tree=/Users/Kahvi'

eval $(thefuck --alias)
export PATH="/usr/local/opt/bison/bin:$PATH"

# eval "$(starship init zsh)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

[[ -s "/Users/Kahvi/.gvm/scripts/gvm" ]] && source "/Users/Kahvi/.gvm/scripts/gvm"

source /usr/local/share/chruby/chruby.sh
chruby ruby-2.7.2


source /Users/Kahvi/.config/broot/launcher/bash/br

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
