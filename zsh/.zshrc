export DF_HOME="$HOME/dotfiles"
export NVM_DIR="$HOME/.nvm"
export ZSH=$HOME/.oh-my-zsh
export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/"
export TERM=xterm-256color

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
alias tx="$DF_HOME/tmux/tmux-sessions.sh"
alias mux="/usr/local/bin/tmuxinator"

# Setting up history backup
HISTSIZE=500000
SAVEHIST=500000
setopt appendhistory
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt inc_append_history_time
setopt EXTENDED_HISTORY

# Enable extended file globs
setopt extendedglob
setopt auto_cd
setopt no_beep
setopt correct
setopt globdots

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

# Fuzzy focus on a window
fw() {
    aerospace list-windows --all | fzf | cut -d'|' -f1 | xargs aerospace focus --window-id
}

# ff - find file with fzf and bat
ff() {
	local file
	file=$(find "${1:-.}" -type f -not -path '*/.*' 2>/dev/null | \
    fzf --preview 'bat --style=numbers --color=always --line-range=:100 {}' --preview-window=right:70%:wrap )  && print -z -- "vim $file"
}

# fh - search in your command history and print selected command
fh() {
  local cmd=$(history | fzf --tac | sed 's/^[ ]*[0-9]*[ ]*//')
  if [[ -n "$cmd" ]]; then
    echo "$cmd" | print -z -- "$cmd"
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "$cmd" | pbcopy
    fi
  fi
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

# Kill all processes running on specified port
port_kill() {
  if [[ -z $1 ]]; then
    echo "Usage: port_kill <port_number>"
    return 1
  fi

  local port=$1
  local pids=($(lsof -i :"$port" -t))

  if [[ ${#pids[@]} -eq 0 ]]; then
    echo "No processes found running on port $port"
    return 1
  fi

  echo "Found ${#pids[@]} process(es) using port $port:"
  lsof -i :"$port" | grep -E "LISTEN|ESTABLISHED"

  echo -n "Kill these processes? [y/N] "
  read confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Attempting graceful termination of PIDs: ${pids[@]}"
    kill ${pids[@]} 2>/dev/null
    sleep 2

    # Check if any processes are still running
    local remaining_pids=($(lsof -i :"$port" -t))
    if [[ ${#remaining_pids[@]} -gt 0 ]]; then
      echo "Some processes still running, forcing termination..."
      kill -9 ${remaining_pids[@]} 2>/dev/null
      echo "All processes on port $port terminated"
    else
      echo "All processes terminated successfully"
    fi
  else
    echo "Operation cancelled"
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

export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"

if [[ -f ~/.oh-my-zsh/completions/_deno ]]; then
  source ~/.oh-my-zsh/completions/_deno
fi

# init zoxide
eval "$(zoxide init zsh)"

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }
