export DF_HOME="$HOME/dotfiles"
export NVM_DIR="$HOME/.nvm"
export ZSH=$HOME/.oh-my-zsh

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if [ "$WORK" = "1" ]; then
    source "$DF_HOME/zsh/work.zsh"
fi

alias showp='echo $PATH | tr -s ":" "\n"'
alias mkdir="mkdir -p"
alias configz="vim $HOME/.zshrc"
alias configv="vim $HOME/.vimrc"
alias vim='nvim'
alias python='python3'
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
alias lg='lazygit'
alias cn='cursor -n .'

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

# configs for MacOS
if [ "$(uname)" = "Darwin" ]; then
  [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
fi

ZSH_THEME=""

plugins=(git colored-man-pages colorize pip python zsh-syntax-highlighting zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# ssh
export SSH_KEY_PATH="$HOME/.ssh/rsa_id"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Adding pure prompt
if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm" ]; then
  fpath+=/opt/homebrew/share/zsh/site-functions
else
  fpath+=$HOME/.zsh/pure
fi
autoload -U promptinit
promptinit
prompt pure

## FUNCTIONS

# fds - cd to selected directory
fds() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
    -o -type d -print 2>/dev/null | fzf +m) &&
    cd "$dir"
}

# ff - find file with fzf and bat
ff() {
	local file
	file=$(find "${1:-.}" -type f -not -path '*/.*' 2>/dev/null | \
    fzf --preview 'bat --style=numbers --color=always --line-range=:100 {}' --preview-window=right:70%:wrap )  && print -z -- "vim $file"
}

# fh - search in your command history and print selected command
fh() {
	local cmd=$(( [ -n "$ZSH_NAME" ] && fc -l 1 || history ) | fzf +s --tac | sed 's/ *[0-9]* *//')
	[[ -n "$cmd" ]] && echo "$cmd" | pbcopy && print -z -- "$cmd"
}

# fs - determine size of a file or total size of a directory.
fs() {
  if du -b /dev/null >/dev/null 2>&1; then
    local arg=-sbh
  else
    local arg=-sh
  fi

  if [[ -n "$@" ]]; then
    du $arg -- "$@"
  else
    du $arg .[^.]* *
  fi
}

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# subl
export PATH="/Applications/Sublime Text.app/Contents/SharedSupport/bin:$PATH"

# bun completions
[ -s "/Users/iamkahvi/.bun/_bun" ] && source "/Users/iamkahvi/.bun/_bun"

# deno
export PATH="/Users/iamkahvi/.local/bin:/Users/iamkahvi/.deno/bin:$PATH"

if [[ -f ~/.oh-my-zsh/completions/_deno ]]; then
  source ~/.oh-my-zsh/completions/_deno
fi

# init zoxide
eval "$(zoxide init zsh)"

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
