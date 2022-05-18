export DF_HOME="$HOME/dotfiles"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

alias showp='echo $PATH | tr -s ":" "\n"'
alias configz='vim ~/.zshrc'
alias configv='vim ~/.vimrc'
alias vim='nvim'
alias python='python3'

if [[ -n $SPIN_WORKSPACE ]]; then
 alias spin='echo $SPIN_WORKSPACE'
fi

# alias smlr='socat READLINE EXEC:sml'
# alias cppcompile='c++ -std=c++11 -stdlib=libc++'

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

ZSH_THEME=""

plugins=(git colored-man-pages colorize pip python zsh-syntax-highlighting zsh-autosuggestions)
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

## FUNCTIONS

# fds - cd to selected directory
fds() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
				  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}

# ff - find file with fzf and bat
ff() {
  local file
  file=$(find ${1:-.} -path '*/\.*' -prune \
                                  -o -type f -print 2> /dev/null | fzf --preview 'cat {}' +m) &&
  vim "$file"
}

# fh - search in your command history and execute selected command
fh() {
  print -z $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}

# fs - determine size of a file or total size of a directory.
fs()
{
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi

	if [[ -n "$@" ]]; then
		du $arg -- "$@";
	else
		du $arg .[^.]* *;
	fi
}

if [ -e $DF_HOME/dircolors ]; then
  eval $(dircolors $DF_HOME/dircolors)
fi

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Adding pure prompt
if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm" ]; then
  fpath+=/opt/homebrew/share/zsh/site-functions
else
  fpath+=$HOME/.zsh/pure
fi
autoload -U promptinit; promptinit
prompt pure

# Load configs for MacOS. Does nothing if not on MacOS
if [ "$(uname)" = "Darwin" ]; then
  source $DF_HOME/macos.zsh
  # Adding dev
  [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh
  if [ -e /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

  [[ -f /opt/dev/sh/chruby/chruby.sh ]] && type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; }

  [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)
fi
