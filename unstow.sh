#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Unstowing dotfiles from: $DOTFILES_DIR${NC}"

# Check if stow is installed
if ! command -v stow &> /dev/null; then
    echo -e "${RED}GNU Stow is not installed. Please install it first.${NC}"
    exit 1
fi

# Define packages - same as in setup.sh
PACKAGES=(
    "aerospace"
    "git"
    "ghostty"
    "hammerspoon"
    "karabiner"
    "kitty"
    "tmux"
    "vim"
    "vscode"
    "zsh"
    # "fish"
    # "hyper"
    # "iterm2"
    # "nginx"
)

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    echo "Unstowing all packages..."
    UNSTOW_PACKAGES=("${PACKAGES[@]}")
else
    UNSTOW_PACKAGES=("$@")
fi

# Unstow packages
for package in "${UNSTOW_PACKAGES[@]}"; do
    if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
        echo -e "${YELLOW}Package directory not found: $package${NC}"
        continue
    fi

    echo -e "${GREEN}Unstowing: $package${NC}"

    if stow -D -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>/dev/null; then
        echo -e "${GREEN}✓ $package unstowed successfully${NC}"
    else
        echo -e "${YELLOW}! $package may not have been fully stowed${NC}"
    fi
done

# Special handling for VSCode on macOS
if [[ " ${UNSTOW_PACKAGES[@]} " =~ " vscode " ]]; then
    echo -e "${GREEN}Removing VSCode symlinks...${NC}"
    VSCODE_DIR="$HOME/Library/Application Support/Code/User"

    if [[ -d "$VSCODE_DIR" ]]; then
        for file in settings.json keybindings.json snippets; do
            if [[ -L "$VSCODE_DIR/$file" ]]; then
                rm "$VSCODE_DIR/$file"
                echo -e "${GREEN}✓ Removed $file symlink${NC}"
            fi
        done
    fi
fi

echo -e "${GREEN}Unstow complete!${NC}"
