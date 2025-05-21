# Adding dev
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

if [ -e /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh ]; then . /Users/kahvipatel/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby() {
	source /opt/dev/sh/chruby/chruby.sh
	chruby "$@"
}; }

export OPENAI_API_KEY=""

alias gwpm="dev cd web-pixels-manager"
alias llmc="llm chat -m openai_proxy"
alias dus="dev up && dev s"
alias gtco="gt checkout"

function feat() {
  if [ -z "$1" ]; then
    echo 'Error: Feature name is required.' >&2
    return 1
  fi

  # Get the git username from config
  local git_username=$(git config user.name | tr '[:upper:] ' '[:lower:]-' | tr -d '.')

  # If username is empty, fall back to system username
  if [ -z "$git_username" ]; then
    git_username=$(whoami)
  fi

  git checkout -b ${git_username}/$1
}

# Created by `pipx` on 2025-03-04 18:14:47
export PATH="$PATH:/Users/kahvi/.local/bin"
