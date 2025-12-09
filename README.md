# dotfiles

Declarative dotfiles managed with [Home Manager](https://nix-community.github.io/home-manager/) and a Nix flake.

## Prerequisites
- Install [Nix](https://nixos.org/download.html) with flakes enabled.
- On macOS, install [`nix-darwin`](https://github.com/lnl7/nix-darwin) if you would like to manage system settings alongside the Home Manager configuration.

## Usage
```bash
# Switch to the macOS configuration
home-manager switch --flake .#kahvi-macbook

# Switch to the Linux configuration
home-manager switch --flake .#kahvi-linux
```

The `modules/` tree mirrors logical domains (shells, terminals, editors, etc.) and reuses the existing configuration files under this repo via `home.file`/`xdg.configFile`. Helper scripts are installed into `~/.local/bin` automatically.

## Hosts
- `kahvi-macbook`: macOS user environment (AeroSpace, Hammerspoon, Karabiner, iTerm2 profiles).
- `kahvi-linux`: Linux workstation profile (i3 window manager and related tooling).

Add new hosts by extending `homeConfigurations` in `flake.nix`; host-specific switches can be passed via `extraModules` or `extraSpecialArgs`.

## Manual / TODO
- Proprietary tooling living under `/opt/dev` and GUI apps such as Tailscale are still managed outside of Nix.
- Nginx configs under `nginx/` remain manual; consider migrating to a server-specific flake if those hosts are later managed with NixOS.
