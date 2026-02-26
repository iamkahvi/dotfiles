export DF_HOME="$HOME/dotfiles"
export NVM_DIR="$HOME/.nvm"
export ZSH=$HOME/.oh-my-zsh

add_path_if_dir() {
  [[ -d "$1" ]] && path=("$1" $path)
}

if [[ "$OSTYPE" == darwin* && -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
  export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/"
fi
# Let the terminal emulator set TERM; hardcoding breaks tmux/zellij

_lazy_load_nvm() {
  unset -f nvm node npm npx corepack
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm() { _lazy_load_nvm; nvm "$@"; }
node() { _lazy_load_nvm; node "$@"; }
npm() { _lazy_load_nvm; npm "$@"; }
npx() { _lazy_load_nvm; npx "$@"; }
corepack() { _lazy_load_nvm; corepack "$@"; }

alias mkdir="mkdir -p"
alias vim='nvim'
alias python='python3'
if [[ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi
alias lg='lazygit'
alias cn='code -n .'
alias j="zellij"
alias oc="opencode"
alias c="claude --dangerously-skip-permissions"
spi() {
  local cmd
  cmd="$($DF_HOME/pi/search_sessions.sh -p $HOME/.pi/agent-shopify/sessions -u "$@")" || return
  [[ -n "$cmd" ]] && print -z -- "$cmd"
}

alias ,p='echo $PATH | tr -s ":" "\n"'
alias ,z="vim $HOME/.zshrc"
alias ,v="vim $HOME/.vimrc"
alias ,tx="$DF_HOME/tmux/tmux-sessions.sh"
alias ,mux="tmuxinator"
alias ,z='source ~/.zshrc'
alias ,gh='gh browse .'

# count unique lines
alias -g ,c='|sort|uniq -c|sort -n|less -F'
# count unique lines without sorting
alias -g ,m='|less -F'
# unique lines
alias -g ,u='|sort|uniq|less -F'
# change default seperator from space to newline for xargs
alias xargs="xargs -d '\n'"

# Load the function to edit the command line
autoload -U edit-command-line
# Create a custom widget from that function
zle -N edit-command-line
# Bind it to a shortcut (Ctrl+x, then Ctrl+e)
bindkey '^x^e' edit-command-line

# Setting up history
HISTSIZE=500000
SAVEHIST=500000
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Enable extended file globs
setopt extendedglob
setopt auto_cd
setopt no_beep
setopt correct
setopt globdots

setopt interactivecomments
unsetopt list_ambiguous

for brew_prefix in /opt/homebrew /home/linuxbrew/.linuxbrew /usr/local; do
  if [[ -x "$brew_prefix/bin/brew" ]]; then
    export HOMEBREW_PREFIX="$brew_prefix"
    export HOMEBREW_CELLAR="$brew_prefix/Cellar"
    export HOMEBREW_REPOSITORY="$brew_prefix"
    [[ -d "$brew_prefix/share/zsh/site-functions" ]] && fpath[1,0]="$brew_prefix/share/zsh/site-functions"
    add_path_if_dir "$brew_prefix/bin"
    add_path_if_dir "$brew_prefix/sbin"
    [ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}"
    [[ -d "$brew_prefix/share/info" ]] && export INFOPATH="$brew_prefix/share/info:${INFOPATH:-}"
    break
  fi
done

# asdf (cross-platform, no warnings if missing)
if [[ -d "${ASDF_DATA_DIR:-$HOME/.asdf}" ]]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

if ! command -v asdf >/dev/null 2>&1; then
  for asdf_sh in \
    "${ASDF_DATA_DIR:-$HOME/.asdf}/asdf.sh" \
    /opt/homebrew/opt/asdf/libexec/asdf.sh \
    /usr/local/opt/asdf/libexec/asdf.sh \
    /opt/asdf-vm/asdf.sh; do
    [[ -r "$asdf_sh" ]] && source "$asdf_sh" && break
  done
fi

ZSH_THEME=""
ZSH_DISABLE_COMPFIX=true

plugins=(git colored-man-pages zsh-syntax-highlighting zsh-autosuggestions)
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

[[ -z "$HOMEBREW_PREFIX" ]] && fpath+=$HOME/.zsh/pure
autoload -U promptinit
promptinit
if prompt -l | grep -qx "pure"; then
  prompt pure
fi

name() {
	kitty @ set-tab-title $1
}

fcd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
    -o -type d -print 2>/dev/null | fzf +m) &&
    cd "$dir"
}

frg() {
  local selected
  selected=$(rg --color=always --line-number --no-heading --smart-case "${*:-}" |
    fzf --ansi \
        --color "hl:-1:underline,hl+:-1:underline:reverse" \
        --delimiter : \
        --preview 'bat --color=always {1} --highlight-line {2}' \
        --preview-window 'up,60%,border-bottom,+{2}+3/3,~3')

  if [[ -n "$selected" ]]; then
    local file=$(echo "$selected" | cut -d':' -f1)
    local line=$(echo "$selected" | cut -d':' -f2)
    print -z -- "vim +${line} ${file}"
  fi
}

ff() {
  local file
  file=$(rg --files --hidden --follow --glob '!.git/*' "${1:-.}" 2>/dev/null | \
    fzf --preview 'bat --style=numbers --color=always --line-range=:100 {}' \
        --preview-window=right:70%:wrap) && print -z -- "vim $file"
}

fh() {
  local cmd=$(history | fzf --tac | sed 's/^[ ]*[0-9]*[ ]*//')
  if [[ -n "$cmd" ]]; then
    echo "$cmd" | print -z -- "$cmd"
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "$cmd" | pbcopy
    fi
  fi
}

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

,pkill() {
  if [[ -z $1 ]]; then
    echo "Usage: ,port-kill <port_number>"
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
[[ -d "/Applications/Sublime Text.app/Contents/SharedSupport/bin" ]] && add_path_if_dir "/Applications/Sublime Text.app/Contents/SharedSupport/bin"

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# go
export PATH="$HOME/go/bin:$PATH"

# deno
export PATH="$HOME/.deno/bin:$PATH"

for pg_bin in \
  "${HOMEBREW_PREFIX:-}/opt/postgresql@15/bin" \
  /usr/lib/postgresql/15/bin; do
  [[ -d "$pg_bin" ]] && add_path_if_dir "$pg_bin"
done

if [[ -f ~/.oh-my-zsh/completions/_deno ]]; then
  source ~/.oh-my-zsh/completions/_deno
fi

# init zoxide
eval "$(zoxide init zsh)"

if [ "$WORK" = "1" ]; then
    source "$DF_HOME/zsh/work.zsh"
fi

if command -v ruby >/dev/null 2>&1 && [[ -f "$HOME/.local/try.rb" ]]; then
  eval "$(ruby ~/.local/try.rb init ~/src/tries)"
fi

export PATH="$HOME/.local/bin:$PATH"
