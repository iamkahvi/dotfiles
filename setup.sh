#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Setting up dotfiles from: $DOTFILES_DIR${NC}"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Install GNU Stow if not present
if ! command -v stow &> /dev/null; then
    echo -e "${YELLOW}Installing GNU Stow...${NC}"
    brew install stow
fi

# Define packages to stow
# Comment out any you don't want to symlink
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
    # "fish"      # Uncomment if using fish shell
    # "hyper"     # Uncomment if using Hyper terminal
    # "iterm2"    # Uncomment if using iTerm2
    # "nginx"     # Uncomment if needed
)

# Function to check if a directory/file would conflict
check_conflicts() {
    local package=$1
    local conflicts=()

    # Use stow's dry-run to check for conflicts
    if ! stow -n -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>&1 | grep -q "conflict"; then
        return 0
    fi

    # Get list of conflicts
    while IFS= read -r line; do
        if [[ $line =~ "existing target is" ]]; then
            local conflict=$(echo "$line" | sed -n 's/.*: \(.*\)/\1/p')
            conflicts+=("$conflict")
        fi
    done < <(stow -n -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>&1)

    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${YELLOW}Conflicts found for $package:${NC}"
        printf '%s\n' "${conflicts[@]}"
        return 1
    fi

    return 0
}

# Function to backup existing files
backup_existing() {
    local file=$1
    local backup_dir="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

    mkdir -p "$backup_dir"

    if [[ -e "$file" ]]; then
        echo -e "${YELLOW}Backing up existing file: $file${NC}"
        mv "$file" "$backup_dir/"
    fi
}

# Main stow process
echo -e "${GREEN}Stowing dotfiles...${NC}"

for package in "${PACKAGES[@]}"; do
    if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
        echo -e "${YELLOW}Package directory not found: $package${NC}"
        continue
    fi

    echo -e "${GREEN}Processing: $package${NC}"

    # Check for conflicts
    if ! check_conflicts "$package"; then
        read -p "Do you want to backup and replace existing files? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Get conflicting files and backup them
            while IFS= read -r line; do
                if [[ $line =~ "existing target is" ]]; then
                    local conflict="$HOME/$(echo "$line" | sed -n 's/.*: \(.*\)/\1/p')"
                    backup_existing "$conflict"
                fi
            done < <(stow -n -d "$DOTFILES_DIR" -t "$HOME" "$package" 2>&1)
        else
            echo -e "${YELLOW}Skipping $package${NC}"
            continue
        fi
    fi

    # Stow the package
    if stow -d "$DOTFILES_DIR" -t "$HOME" "$package"; then
        echo -e "${GREEN}✓ $package stowed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to stow $package${NC}"
    fi
done

# Special handling for VSCode settings on macOS
if [[ " ${PACKAGES[@]} " =~ " vscode " ]]; then
    echo -e "${GREEN}Setting up VSCode...${NC}"
    VSCODE_DIR="$HOME/Library/Application Support/Code/User"

    if [[ -d "$VSCODE_DIR" ]]; then
        # Remove existing symlinks or backup existing files
        for file in settings.json keybindings.json snippets; do
            if [[ -e "$VSCODE_DIR/$file" ]]; then
                if [[ -L "$VSCODE_DIR/$file" ]]; then
                    rm "$VSCODE_DIR/$file"
                else
                    backup_existing "$VSCODE_DIR/$file"
                fi
            fi
        done

        # Create symlinks for VSCode
        if [[ -d "$DOTFILES_DIR/vscode/.config/Code/User" ]]; then
            ln -sf "$DOTFILES_DIR/vscode/.config/Code/User/"* "$VSCODE_DIR/"
            echo -e "${GREEN}✓ VSCode settings linked${NC}"
        fi
    fi
fi

echo -e "${GREEN}Dotfiles setup complete!${NC}"
echo -e "${YELLOW}Note: You may need to restart your terminal for some changes to take effect.${NC}"

# Optional: Run additional setup scripts
if [[ -d "$DOTFILES_DIR/setups" ]]; then
    echo -e "${GREEN}Found setup scripts directory${NC}"
    read -p "Do you want to run additional setup scripts? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for setup_script in "$DOTFILES_DIR/setups"/*.sh; do
            if [[ -f "$setup_script" ]]; then
                echo -e "${GREEN}Running: $(basename "$setup_script")${NC}"
                bash "$setup_script"
            fi
        done
    fi
fi
