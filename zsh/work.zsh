# Adding dev
[ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

# Added by tec agent
[[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]] && eval "$("$HOME/.local/state/tec/profiles/base/current/global/init" zsh)"

if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then . "$HOME/.nix-profile/etc/profile.d/nix.sh"; fi # added by Nix installer

[[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby() {
	source /opt/dev/sh/chruby/chruby.sh
	chruby "$@"
}; }

# OPENAI_API_KEY: set in ~/.secrets, not in dotfiles
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"

alias gwpm="dev cd web-pixels-manager"
alias llmc="llm chat -m openai_proxy"
alias dus="dev up && dev s"
alias gtco="gt checkout"
alias c="devx claude"
alias pi="devx pi"

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
export PATH="$PATH:$HOME/.local/bin"

yellwhenshipped() {
    if [ -z "$1" ]; then
        echo "Usage: yellwhenshipped <PR_NUMBER>"
        return 1
    fi

    local PR_NUMBER=$1

    _yellwhenshipped() {
        local PR_NUMBER=$1
        local TIMEOUT_SECONDS=86400  # 24 hours
        local start_time=$(date +%s)

        while true; do
            local current_time=$(date +%s)
            local elapsed_time=$((current_time - start_time))

            if [ $elapsed_time -ge $TIMEOUT_SECONDS ]; then
                echo "Timeout reached after 24 hours. Stopping monitoring for PR $PR_NUMBER."
                osascript -e "display alert \"PR $PR_NUMBER monitoring timed out\" message \"Stopped monitoring after 24 hours.\"" > /dev/null
                break
            fi

            local output=$(DEV_NO_AUTO_UPDATE=1 /opt/dev/bin/dev conveyor is-it-shipped "$PR_NUMBER" 2>&1)
            if echo "$output" | grep -q "is deployed for zone"; then
                # Extract PR name from message like "Your PR (PR Name (#12345)) is deployed for zone"
                local pr_name=$(echo "$output" | sed -n 's/.*Your PR (\(.*\)) is deployed for zone.*/\1/p')
                if [ -n "$pr_name" ]; then
                    osascript -e "display alert \"PR is deployed!\" message \"$pr_name has been successfully deployed.\"" > /dev/null
                    echo "PR is deployed: $pr_name"
                else
                    osascript -e "display alert \"$PR_NUMBER is deployed!\" message \"Your PR has been successfully deployed.\"" > /dev/null
                    echo "$PR_NUMBER is deployed!"
                fi
                break
            fi
            sleep 300
        done
    }

    echo "Starting background monitoring for PR $1 (24h timeout)"
    _yellwhenshipped "$PR_NUMBER" &
}
