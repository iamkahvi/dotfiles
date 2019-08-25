# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Adding VSCode
export PATH=$PATH:/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

alias python='python3'
alias showp='echo $PATH | tr -s ":" "\n"'
alias configz='vim ~/.zshrc'
alias configv='vim ~/.vimrc'

eval $( gdircolors -b $HOME/LS_COLORS )

# User Configuration

# Enable extended file globs
setopt extendedglob

setopt auto_cd
setopt no_beep
setopt correct

ZSH_THEME=sammy

plugins=(git colored-man colorize pip python zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

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
