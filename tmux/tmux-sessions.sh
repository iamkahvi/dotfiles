#!/bin/bash

# Path to tmuxinator configs
TMUXINATOR_DIR="$HOME/.config/tmuxinator"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Main function
main() {
  local sessions=$(find "$TMUXINATOR_DIR" -name "*.yml" -exec basename {} .yml \;)

  local selected=$(echo "$sessions" | fzf \
    --ansi \
    --preview-window=right:60% \
    --preview "echo -e '${CYAN}Session: {}${NC}';
    if tmux has-session -t {} 2>/dev/null; then
      echo -e '${GREEN}Status: Running${NC}';
    else
      echo -e '${RED}Status: Not running${NC}';
    fi;
    echo '';
    echo -e '${BLUE}Git info:${NC}';
    root=\$(grep 'root:' '$TMUXINATOR_DIR/{}.yml' | sed 's/root: //' | sed 's|\\\$HOME|$HOME|' | sed 's|<%= ENV\\[\\\"HOME\\\"\\] %>|$HOME|');
      echo -e \"${CYAN}Directory: \$root${NC}\";
      echo -e \"${YELLOW}Branch: \$(cd \"\$root\" && git branch --show-current)${NC}\";
      echo -e \"${BLUE}Changes:${NC}\";
      (cd \"\$root\" && git status --short | grep -E --color=always '^(.M|M.|.A|A.|.D|D.|.R|R.|.C|C.|.U|U.)' || echo -e \"${GREEN}No changes${NC}\");" \
    --bind "ctrl-e:execute(echo {} | sed 's/^/editor:/')+accept" \
    --header "Enter: Open git window | Ctrl+E: Open editor window")

  local mode="git"
  if [[ "$selected" == editor:* ]]; then
    mode="editor"
    selected=$(echo "$selected" | sed 's/editor://')
  fi

  if [ -n "$selected" ]; then
    # Get the project root directory
    local root=$(grep 'root:' "$TMUXINATOR_DIR/$selected.yml" | sed 's/root: //' | sed 's|\$HOME|'"$HOME"'|' | sed 's|<%= ENV\["HOME"\] %>|'"$HOME"'|')

    if [ "$mode" = "editor" ]; then
      # Open cursor in the project directory
      cd "$root" && cursor -n .
    else
      # Open git window (default)
      if tmux has-session -t "$selected" 2>/dev/null; then
        tmux attach -t "$selected"
      else
        tmuxinator start "$selected"
      fi
    fi
  fi
}

# Run main function
main
