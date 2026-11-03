# Ubuntu-only zsh config. Sourced by .zshrc when DOTFILES_PLATFORM=ubuntu.

# apt names bat and fd differently. Alias only when the short name is absent.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi
