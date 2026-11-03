# Sourced by every zsh, including non-interactive shells.
# Sets the two branch axes for the dotfiles: DOTFILES_PLATFORM and DOTFILES_PROFILE.
# See docs/machine-branching-plan.md.

export DF_HOME="${DF_HOME:-$HOME/dotfiles}"

# Machine-local overrides and secrets. Not in git.
# Example on the work Mac:
#   export DOTFILES_PROFILE=work
#   export SHOPIFY_TALENT_TOKEN="..."
[[ -r "$HOME/.zshenv.local" ]] && source "$HOME/.zshenv.local"

export DOTFILES_PROFILE="${DOTFILES_PROFILE:-personal}"

if [[ -z "$DOTFILES_PLATFORM" ]]; then
  case "$OSTYPE" in
    darwin*) DOTFILES_PLATFORM=macos ;;
    *)
      case "$(. /etc/os-release 2>/dev/null; echo "$ID")" in
        arch | omarchy) DOTFILES_PLATFORM=omarchy ;;
        ubuntu)         DOTFILES_PLATFORM=ubuntu ;;
        *)              DOTFILES_PLATFORM=unknown ;;
      esac
      ;;
  esac
fi
export DOTFILES_PLATFORM

[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
