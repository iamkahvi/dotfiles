#!/bin/bash

# Path to tmuxinator configs
TMUXINATOR_DIR="$HOME/.config/tmuxinator"

main() {
  # Get all available sessions using tmuxinator ls
  local sessions_output=$(tmuxinator ls)
  if [ $? -ne 0 ]; then
    gum style --foreground 9 "Failed to get tmuxinator sessions"
    exit 1
  fi

  # Extract just the session names from the output
  local sessions=$(echo "$sessions_output" | grep -v "tmuxinator projects:" | tr -s ' ' '\n' | sed '/^$/d')

  if [ -z "$sessions" ]; then
    gum style --foreground 9 "No tmuxinator sessions found"
    exit 1
  fi

  # Use gum filter to select a session (similar to fzf)
  local selected=$(echo "$sessions" | gum filter --placeholder "Select a tmuxinator session...")

  if [ -z "$selected" ]; then
    gum style --foreground 9 "No session selected"
    exit 0
  fi

  # Get the project root directory
  local root=$(grep 'root:' "$TMUXINATOR_DIR/$selected.yml" | sed 's/root: //' | sed 's|\$HOME|'"$HOME"'|' | sed 's|<%= ENV\["HOME"\] %>|'"$HOME"'|')

  # Display session info
  gum style --foreground 39 --bold "Session: $selected"

  if tmux has-session -t "$selected" 2>/dev/null; then
    gum style --foreground 10 "Status: Running"
  else
    gum style --foreground 9 "Status: Not running"
  fi

  echo
  gum style --foreground 39 --bold "Git info:"
  gum style --foreground 51 "Directory: $root"

  if [ -d "$root/.git" ]; then
    local branch=$(cd "$root" && git branch --show-current)
    gum style --foreground 220 "Branch: $branch"

    gum style --foreground 39 "Changes:"
    local changes=$(cd "$root" && git status --short)
    if [ -n "$changes" ]; then
      echo "$changes" | gum format
    else
      gum style --foreground 10 "No changes"
    fi
  else
    gum style --foreground 9 "Not a git repository"
  fi

  # Ask user what to do
  echo
  local action=$(gum choose "Open tmux session" "Open editor")

  if [ "$action" = "Open editor" ]; then
    # Open cursor in the project directory
    cd "$root" && cursor -n .
  else
    # Open tmux session
    if tmux has-session -t "$selected" 2>/dev/null; then
      tmux attach -t "$selected"
    else
      tmuxinator start "$selected"
    fi
  fi
}

# Run main function
main
