# macOS-only zsh config. Sourced by .zshrc when DOTFILES_PLATFORM=macos.

if [[ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs" ]]; then
  export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/"
fi

if [[ -x "/Applications/Tailscale.app/Contents/MacOS/Tailscale" ]]; then
  alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
fi

# subl
add_path_if_dir "/Applications/Sublime Text.app/Contents/SharedSupport/bin"

obs() {
  if (( $# == 0 )); then
    print -u2 'Usage: obs <file> [file ...]'
    return 2
  fi
  local -a files=("${(@)argv:a}")
  open -a Obsidian "${files[@]}"
}

# Ghostty tab title through the menu. The `tab` function in .zshrc is the portable form.
gname() { osascript -e 'tell application "System Events" to tell process "Ghostty" to tell menu bar 1 to tell menu "View" of menu bar item "View" to click menu item "Change Tab Title..."' -e 'delay 0.3' -e "tell application \"System Events\" to keystroke \"$1\"" -e 'tell application "System Events" to keystroke return'; }
