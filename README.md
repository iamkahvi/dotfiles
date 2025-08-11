# Dotfiles

Personal dotfiles managed with GNU Stow

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the setup script
./setup.sh
```

## What the setup script does

1. **Checks for Homebrew** - Installs it if not present (required for GNU Stow on macOS)
2. **Installs GNU Stow** - If not already installed
3. **Symlinks dotfiles** - Creates symlinks from your home directory to this repository
4. **Handles conflicts** - Prompts to backup existing files before replacing
5. **Special handling for VSCode** - Properly links VSCode settings on macOS

## Managing packages

### Setup all dotfiles
```bash
./setup.sh
```

### Remove all symlinks
```bash
./unstow.sh
```

### Remove specific package symlinks
```bash
./unstow.sh vim tmux
```

### Manually stow a single package
```bash
stow -d ~/dotfiles -t ~ package_name
```

### Manually unstow a package
```bash
stow -D -d ~/dotfiles -t ~ package_name
```

## Available packages

- **aerospace** - Window manager configuration
- **git** - Git configuration (.gitconfig, .gitignore_global)
- **ghostty** - Ghostty terminal configuration
- **hammerspoon** - macOS automation tool
- **karabiner** - Keyboard customization
- **kitty** - Kitty terminal configuration
- **tmux** - Terminal multiplexer configuration
- **vim** - Vim/Neovim configuration
- **vscode** - Visual Studio Code settings
- **zsh** - Zsh shell configuration
- **fish** - Fish shell configuration (commented out by default)
- **hyper** - Hyper terminal configuration (commented out by default)
- **iterm2** - iTerm2 configuration (commented out by default)
- **nginx** - Nginx configuration (commented out by default)

## Customizing packages

Edit the `PACKAGES` array in `setup.sh` and `unstow.sh` to enable/disable specific configurations.

## Directory structure

Each package should follow the structure of where its files belong in your home directory. For example:

```
vim/
├── .vimrc
└── .vim/
    └── ...

git/
├── .gitconfig
└── .gitignore_global

tmux/
└── .tmux.conf
```

## Conflict resolution

If files already exist in your home directory, the setup script will:
1. Detect conflicts using stow's dry-run mode
2. Ask if you want to backup existing files
3. Move existing files to `~/.dotfiles_backup/[timestamp]/`
4. Create the symlinks

## Adding new dotfiles

1. Create a new directory for your package
2. Mirror the home directory structure inside it
3. Add the package name to the `PACKAGES` array in both scripts
4. Run `./setup.sh`

Example:
```bash
# For a new .screenrc file
mkdir screen
echo "your config" > screen/.screenrc
# Edit setup.sh and unstow.sh to add "screen" to PACKAGES
./setup.sh
```

## Troubleshooting

### Permission denied
```bash
chmod +x setup.sh unstow.sh
```

### Stow conflicts
The script automatically handles conflicts, but you can manually check:
```bash
stow -n -v -d ~/dotfiles -t ~ package_name
```

### VSCode settings not linking
VSCode on macOS uses a special directory. The script handles this, but ensure VSCode is installed first.

## Additional setup scripts

Place any additional setup scripts in the `setups/` directory. The main setup script will offer to run them after stowing completes.
