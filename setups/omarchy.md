# Omarchy Setup

This guide configures an Omarchy workstation from this repository.

It does not run `setups/install.sh`.
It does not replace whole configuration directories.
It does not delete an existing configuration file.

## Scope

This guide configures these applications:

- Git
- Zsh
- Ghostty
- Hyprland
- Pi
- Neovim
- Yazi
- Herdr

This guide does not configure these applications:

- Fish
- Kitty
- Zellij
- i3
- macOS-only applications

Use Herdr for terminal workspaces. Do not install Zellij.

## Requirements

- Omarchy is installed.
- This repository is available at `~/dotfiles`.
- `~/.local/bin` is in `PATH`.
- Run commands that need sudo in an interactive terminal.

Install Arch packages with `omarchy pkg add <package>`.
Do not edit files in `/usr/share/omarchy/`.

## Safe Link Procedure

Inspect the source and target before you link a file.
Back up an existing target file. Then create one symlink.

Define this function in the shell that performs the setup:

```sh
backup_and_link() {
  source_file="$1"
  target_file="$2"

  test -f "$source_file"
  mkdir -p "$(dirname "$target_file")"

  if [ -L "$target_file" ] \
    && [ "$(readlink -f "$target_file")" = "$(readlink -f "$source_file")" ]; then
    printf 'Already linked: %s\n' "$target_file"
    return
  fi

  if [ -e "$target_file" ] || [ -L "$target_file" ]; then
    mv "$target_file" "$target_file.pre-dotfiles-$(date +%Y%m%dT%H%M%S%z)"
  fi

  ln -s "$source_file" "$target_file"
}
```

Do not use `ln -sfn`. It can replace an existing link without preserving it.

## Git

Link the Git configuration:

```sh
backup_and_link "$HOME/dotfiles/git/config" "$HOME/.config/git/config"
```

Check the result:

```sh
git config --global --list --show-origin
git config --global --get user.name
git config --global --get user.email
```

The configured identity is `Kahvi Patel <iamkahvi@gmail.com>`.

## Zsh

Install Zsh and its Arch packages:

```sh
omarchy pkg add zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions
omarchy pkg aur add oh-my-zsh-git zsh-pure-prompt
```

Set Zsh as the login shell:

```sh
chsh -s /usr/bin/zsh
getent passwd "$USER" | cut -d: -f1,7
```

Link the configuration:

```sh
backup_and_link "$HOME/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
```

The configuration loads Oh My Zsh from `/usr/share/oh-my-zsh` when a user copy does not exist.
It loads Arch package copies of zsh-autosuggestions and zsh-syntax-highlighting.
It loads the Arch Pure prompt.
It defines `h` as the Herdr alias.
It does not define a Zellij alias.

Open a new terminal after you change the login shell.

## Ghostty

Install Ghostty when it is absent:

```sh
omarchy pkg add ghostty
```

Link the configuration:

```sh
backup_and_link "$HOME/dotfiles/ghostty/config" "$HOME/.config/ghostty/config"
```

Check the configuration:

```sh
ghostty +validate-config
```

The configuration uses `JetBrainsMono Nerd Font`.
It adds `Ctrl+T` to create a tab.

Open a new Ghostty window after you change the configuration.

## Hyprland

Inspect existing keybindings before you replace them:

```sh
omarchy menu keybindings --print
```

Inspect input-device names before you configure a device override:

```sh
hyprctl devices
```

The current configuration uses this pointer-device name:

```text
mosart-semi.-2.4g-wireless-mouse
```

Update `hypr/input.lua` when the connected pointer has a different name.

Link the Hyprland files:

```sh
backup_and_link "$HOME/dotfiles/hypr/bindings.lua" "$HOME/.config/hypr/bindings.lua"
backup_and_link "$HOME/dotfiles/hypr/input.lua" "$HOME/.config/hypr/input.lua"
backup_and_link "$HOME/dotfiles/hypr/looknfeel.lua" "$HOME/.config/hypr/looknfeel.lua"
```

Apply and check the configuration:

```sh
hyprctl reload
hyprctl configerrors
```

`hyprctl configerrors` must produce no output.

The configuration does these things:

- Maps Caps Lock to Control.
- Enables natural scrolling for the configured pointer device.
- Uses a neon-green active border.
- Sets centered-master layout values.
- Maps `Ctrl+J` and `Ctrl+K` to Down and Up.
- Maps `Super+T` to `Ctrl+T`.
- Maps `Super+W` to close a browser tab or close a window.
- Maps `Super+Alt+C` to the centered-master script.

Do not enable the `Alt+Space` Handy binding until this executable exists:

```text
~/.local/bin/handy
```

## Pi

Pi uses `~/.pi/agent`. It does not use `~/.config/pi`.

Link these files:

```sh
backup_and_link "$HOME/dotfiles/pi/settings.json" "$HOME/.pi/agent/settings.json"
backup_and_link "$HOME/dotfiles/pi/models.json" "$HOME/.pi/agent/models.json"
```

Preserve these files and directories:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/sessions/`
- `~/.pi/agent/models-store.json`
- `~/.pi/agent/themes/`
- Omarchy skills in `~/.pi/agent/skills/`

The settings file loads local extensions and skills from `~/dotfiles/pi`.
Restart Pi after you change its global settings.

## Neovim

Link the Neovim entry files:

```sh
backup_and_link "$HOME/dotfiles/vim/init.lua" "$HOME/.config/nvim/init.lua"
backup_and_link "$HOME/dotfiles/vim/.vimrc" "$HOME/.vimrc"
```

Move old Neovim files out of the active configuration directory.
Do not keep old `plugin/` or `lua/` directories in `~/.config/nvim/`.
Neovim can load files in the old `plugin/` directory.

```sh
backup_dir="$HOME/.local/state/dotfiles-backups/nvim-$(date +%Y%m%dT%H%M%S%z)"
mkdir -p "$backup_dir"
find "$HOME/.config/nvim" -mindepth 1 -maxdepth 1 ! -name init.lua -exec mv -t "$backup_dir" -- {} +
```

Start Neovim once after the links are in place.
`lazy.nvim` downloads the plugins declared in `vim/init.lua`.

`lazy.nvim` writes `~/.config/nvim/lazy-lock.json`.
The repository does not track this lockfile yet.
A new setup can therefore install newer plugin revisions.

## Yazi

Install Yazi when it is absent:

```sh
omarchy pkg add yazi
```

Link the configuration files:

```sh
backup_and_link "$HOME/dotfiles/yazi/yazi.toml" "$HOME/.config/yazi/yazi.toml"
backup_and_link "$HOME/dotfiles/yazi/keymap.toml" "$HOME/.config/yazi/keymap.toml"
backup_and_link "$HOME/dotfiles/yazi/package.toml" "$HOME/.config/yazi/package.toml"
```

Install the pinned Yazi plugin:

```sh
ya pkg install
ya pkg list
```

The `Ctrl+Y` and `c y` bindings use the `copy-file-contents` plugin.
The plugin uses `wl-copy` on Linux.

The `e c` binding needs `code`.
The `e p` binding needs `pumice`.
Do not use these bindings until the commands are installed.

## Herdr

Check that Herdr is installed:

```sh
herdr --version
```

Link the configuration:

```sh
backup_and_link "$HOME/dotfiles/herdr/config.toml" "$HOME/.config/herdr/config.toml"
herdr config check
```

Link the local Pi panel plugin:

```sh
herdr plugin link "$HOME/dotfiles/herdr/plugins/pi-panel"
herdr plugin list
```

The plugin manifest must start Pi from `PATH`:

```toml
command = ["pi"]
```

Do not use a hardcoded macOS Bun path.

Install the Pi integration:

```sh
herdr integration install pi
herdr integration status
```

Restart Pi after you install the integration.
Start or restart Herdr after you change its configuration.

The configuration uses `Ctrl+A` as the prefix key.
Press `Ctrl+A`, then `P`, to open, focus, or close the Pi side panel.

## Scripts

Do not link scripts into `~/.local/bin` by default.

Hyprland runs `toggle-centered-master` from its `Super+Alt+C` binding.
It does not need a global command.

Do not expose these scripts on Omarchy:

- `tmux-sessionizer`
- `immich-to-r2.sh`
- `open-kitty-term.rb`
- `blockit`

`tmux-sessionizer` is for tmux.
`immich-to-r2.sh` and `open-kitty-term.rb` are macOS-specific.
`blockit` changes `/etc/hosts`. It needs Linux DNS-cache support before use.

## Optional tmux State

The repository contains a tmux configuration.
Herdr is the preferred terminal workspace manager on this machine.
Do not install TPM or tmux plugins unless tmux becomes necessary.
