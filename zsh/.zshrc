# Common zsh config for all machines.
# Platform and profile parts live in zsh/$DOTFILES_PLATFORM.zsh and zsh/work.zsh.
# zsh/.zshenv sets DOTFILES_PLATFORM and DOTFILES_PROFILE.

export DF_HOME="${DF_HOME:-$HOME/dotfiles}"
export NVM_DIR="$HOME/.nvm"
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
[[ -r "/usr/share/oh-my-zsh/oh-my-zsh.sh" && ! -r "$ZSH/oh-my-zsh.sh" ]] && ZSH="/usr/share/oh-my-zsh"

add_path_if_dir() {
  [[ -d "$1" ]] && path=("$1" $path)
}

# Sources the output of an init command. Runs the command again only when the key file is newer than the cache.
# The output must not depend on the environment. Use for static init scripts only.
# Usage: source_cached <name> <key-file> <command...>
source_cached() {
  local name=$1 key=$2; shift 2
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/$name.zsh"
  if [[ ! -s $cache || $key -nt $cache ]]; then
    mkdir -p "${cache:h}"
    "$@" >| "$cache" || { rm -f "$cache"; return 1; }
  fi
  source "$cache"
}

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

mkcd() { command mkdir -p "$@" && cd "${@[-1]}"; }
alias vim='nvim'
alias python='python3'
alias lg='lazygit'
alias cn='code -n .'
alias h='herdr'
alias oc="opencode"
alias c="claude --dangerously-skip-permissions"
spi() {
  local cmd
  cmd="$($DF_HOME/pi/search_sessions.sh -p $HOME/.pi/agent/sessions -u "$@")" || return
  [[ -n "$cmd" ]] && print -z -- "$cmd"
}

alias ,p='echo $PATH | tr -s ":" "\n"'
alias ,cz="vim $HOME/.zshrc"
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

# oh-my-zsh libs and plugins without the oh-my-zsh framework (oh-my-zsh.sh).
# The framework adds about 30 ms at startup: compaudit, `git rev-parse` for the compdump check, and update checks.
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
[[ -d $ZSH_CACHE_DIR ]] || mkdir -p "$ZSH_CACHE_DIR"

# Use the completion dump without checks when it is less than 20 hours old.
# Otherwise look for new completion files and update the dump.
# To load new completions now: rm ~/.cache/zsh/zcompdump-*
autoload -Uz compinit
_zcompdump="$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
if [[ -n $_zcompdump(#qN.mh-20) ]]; then
  compinit -C -d "$_zcompdump"
else
  compinit -u -d "$_zcompdump"
  touch "$_zcompdump"
  zcompile "$_zcompdump"
fi
unset _zcompdump

# Pure shows the git status. Do not register the oh-my-zsh async git prompt hook.
zstyle ':omz:alpha:lib:git' async-prompt no
for _omz_lib in functions git completion history key-bindings directories misc \
  theme-and-appearance grep clipboard termsupport; do
  [[ -r "$ZSH/lib/$_omz_lib.zsh" ]] && source "$ZSH/lib/$_omz_lib.zsh"
done
unset _omz_lib
# Completion colors are the same as ls colors. oh-my-zsh.sh sets this after the theme.
[[ -z "$LS_COLORS" ]] || zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# The git plugin runs `git version` only to select aliases for git 2.8, 2.13, and 2.30 or later.
# Give it a fixed answer. On macOS, `git version` takes 8-15 ms.
git() { [[ $1 == version ]] && print 'git version 2.30.0' || command git "$@" }
[[ -r "$ZSH/plugins/git/git.plugin.zsh" ]] && source "$ZSH/plugins/git/git.plugin.zsh"
unfunction git
[[ -r "$ZSH/plugins/colored-man-pages/colored-man-pages.plugin.zsh" ]] && source "$ZSH/plugins/colored-man-pages/colored-man-pages.plugin.zsh"
# Bind the autosuggest widgets one time at the first prompt, not before each prompt (6 ms each).
ZSH_AUTOSUGGEST_MANUAL_REBIND=1
for plugin in \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" \
  "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"; do
  [[ -r "$plugin" ]] && source "$plugin" && break
done

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# ssh
export SSH_KEY_PATH="$HOME/.ssh/rsa_id"

# fzf key bindings. First match wins:
#   macOS (brew install script): ~/.fzf.zsh
#   Arch package:                /usr/share/fzf/key-bindings.zsh
#   Ubuntu apt package:          /usr/share/doc/fzf/examples/key-bindings.zsh
if [[ -r ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
else
  for fzf_dir in /usr/share/fzf /usr/share/doc/fzf/examples; do
    if [[ -r "$fzf_dir/key-bindings.zsh" ]]; then
      source "$fzf_dir/key-bindings.zsh"
      [[ -r "$fzf_dir/completion.zsh" ]] && source "$fzf_dir/completion.zsh"
      break
    fi
  done
fi

if [[ -r /usr/share/zsh/functions/Prompts/prompt_pure_setup ]]; then
  autoload -Uz prompt_pure_setup
  prompt_pure_setup
else
  [[ -d "$HOME/.zsh/pure" ]] && fpath=("$HOME/.zsh/pure" $fpath)
  autoload -U promptinit
  promptinit
  if prompt -l | grep -qw "pure"; then
    prompt pure
  fi
fi

cmux-name() {
  if [[ -z "${CMUX_SURFACE_ID:-}" ]]; then
    print -u2 "cmux-name: CMUX_SURFACE_ID is not set"
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    print -u2 'usage: cmux-name "tab name"'
    return 2
  fi

  command cmux rename-tab --surface "$CMUX_SURFACE_ID" "$*"
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
    echo "Usage: ,pkill <port_number>"
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
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# try (https://github.com/tobi/try)
if command -v try >/dev/null 2>&1; then
  source_cached try-init "$commands[try]" try init ~/src/tries
elif command -v ruby >/dev/null 2>&1 && [[ -f "$HOME/.local/try.rb" ]]; then
  source_cached try-init "$HOME/.local/try.rb" ruby ~/.local/try.rb init ~/src/tries
fi

export PATH="$HOME/.local/bin:$PATH"

# Rename Ghostty tab title
DISABLE_AUTO_TITLE="true"
tab() {
  __custom_tab_title="$*"
  printf '\033]2;%s\007' "$*" > "$(tty)"
}
_custom_tab_title_precmd() {
  [[ -n "$__custom_tab_title" ]] && printf '\033]2;%s\007' "$__custom_tab_title" > "$(tty)"
}
add-zsh-hook precmd _custom_tab_title_precmd

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# OpenClaw Completion
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

# Machine-specific values live outside git:
#   ~/.zshenv.local  secrets and the profile (TS_SITE_HOST_URL, TS_SITE_API_TOKEN, SHOPIFY_TALENT_TOKEN)
#   ~/.zshrc.local   interactive-only extras

# Platform file, then profile file. Both are optional.
[[ -r "$DF_HOME/zsh/$DOTFILES_PLATFORM.zsh" ]] && source "$DF_HOME/zsh/$DOTFILES_PLATFORM.zsh"
[[ "$DOTFILES_PROFILE" == work ]] && source "$DF_HOME/zsh/work.zsh"
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Load syntax highlighting last so it can install its ZLE hooks.
for plugin in \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  "${ZSH_CUSTOM:-$ZSH/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh" \
  "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"; do
  [[ -r "$plugin" ]] && source "$plugin" && break
done
