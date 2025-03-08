#!/bin/bash

# Path to tmuxinator configs
TMUXINATOR_DIR="$HOME/.config/tmuxinator"

# Handle Ctrl+C gracefully
trap 'echo; gum style --foreground 9 "Operation cancelled"; exit 0' INT

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
  gum style --align center --width 50 --margin "1 2" --padding "1 2" --border-foreground 39 --border rounded \
    --foreground 39 --bold "[$selected]"

  if tmux has-session -t "$selected" 2>/dev/null; then
    gum style --foreground 10 "Status: Running"
  else
    gum style --foreground 9 "Status: Not running"
  fi

  echo
  local branch=$(cd "$root" && git branch --show-current 2>/dev/null)
  gum style --foreground 39 "Branch: $branch"

  gum style --foreground 39 "Changes:"
  local changes=$(cd "$root" && git status --short 2>/dev/null)
  if [ -n "$changes" ]; then
    echo "$changes" | gum format
  else
    gum style --foreground 10 "No changes"
  fi

  # Ask user what to do with expanded options
  echo
  local action=$(gum choose \
    "editor" \
    "server" \
    "git")

  # Check if action was selected (could be empty if user pressed Ctrl+C)
  if [ -z "$action" ]; then
    gum style --foreground 9 "No action selected"
    exit 0
  fi

  case "$action" in
    "editor")
      # Open cursor in the project directory
      cd "$root" && cursor -n .
      ;;
    "server")
      # Open tmux session to the server window
      if tmux has-session -t "$selected" 2>/dev/null; then
        tmux a -t "$selected:server"
      else
        gum style --foreground 220 "Session not running. Starting session..."
        tmuxinator start "$selected" startup=server
      fi
      ;;
    "git")
      # Open tmux session to the server window
      if tmux has-session -t "$selected" 2>/dev/null; then
        tmux a -t "$selected:git"
      else
        gum style --foreground 220 "Session not running. Starting session..."
        tmuxinator start "$selected" startup=git
      fi
      ;;
    *)
  esac
}

# Run main function
main
