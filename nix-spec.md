# Nix Migration Plan

## Goal
Port the existing dotfiles setup to a declarative Nix flake that uses home-manager for per-user configuration on macOS and Linux hosts.

## Inventory And Grouping
- **Shared configs**: Fish, Zsh, tmux, Zellij, Neovim, VS Code, kitty, Ghostty, Hyper, git, scripts, general session variables.
- **macOS specific**: AeroSpace, Hammerspoon, Karabiner, iTerm2 profiles, macOS-only binaries (e.g., Tailscale.app launcher).
- **Linux specific**: i3 config, legacy `install.sh` apt packages, system services assumptions.
- **Server assets**: Nginx configs and certificates (likely remain manual unless host is also managed by Nix).
- **External dependencies**: gum, tmuxinator, fzf, bat, zoxide, dev tooling under `/opt/dev`, cursor editor, Sublime Text, etc.

## Flake Structure
1. **Inputs**: `nixpkgs`, `home-manager`, plus `darwin` and/or `nixos` if system-level configs are desired.
2. **Outputs**:
   - `homeConfigurations.<host>` for each target machine/user.
   - Optional `devShells` with the same toolchain for local testing.
3. **Module layout**: Create `modules/` directory containing logical splits:
   - `shell.nix` (Fish, Zsh, env vars, aliases).
   - `terminals.nix` (kitty, Ghostty, Hyper).
   - `tmux.nix`, `zellij.nix`.
   - `editors.nix` (Neovim, VS Code).
   - `git.nix` (global .gitconfig).
   - `mac.nix` (AeroSpace, Hammerspoon, Karabiner, macOS-only packages).
   - `linux.nix` (i3, Linux-only packages/services).
   - `scripts.nix` for installing helper scripts into PATH.

## Translating Configs
- **Fish**: Use `programs.fish` with `interactiveShellInit`, `shellInit`, and `functions`. Migrate abbreviations/functions from `fish/config.fish`.
- **Zsh**: Use `programs.zsh` to add aliases, environment variables, and the `feat`/`yellwhenshipped` functions from `zsh/work.zsh`. Gate work-specific bits behind host variables if needed.
- **tmux/Zellij**: Use `programs.tmux` and `programs.zellij`. Copy shell scripts into `home.file` or `xdg.configFile`, mark as executable.
- **Neovim**: Use `programs.neovim` with `extraConfig` and plugin list. Embed `vim/init.lua` via `builtins.readFile` or refactor into Lua snippets stored in `files/`.
- **VS Code**: Use `programs.vscode` with `userSettings` and `keybindings`, plus `extensions` list mirroring current usage.
- **Terminals**: Deploy config files via `home.file` or `xdg.configFile`. Example: `xdg.configFile."kitty/kitty.conf".text = builtins.readFile ./kitty/kitty.conf;`
- **Window managers**: Similar `xdg.configFile` entries for AeroSpace (`.aerospace.toml`), Hammerspoon (`init.lua`), Karabiner (`karabiner.json`), i3 (`config`). Apply host-specific imports.
- **Nginx**: If kept under user control, place under `home.file`. If system-level, document manual deployment or plan a separate NixOS module.

## Packages And Activation
- Use `home.packages` in shared module for CLI tools (fzf, bat, fd, ripgrep, gum, tmuxinator, zoxide, neovim, kitty, tmux, gh, etc.).
- Add platform-specific packages (e.g., i3, feh) in `linux.nix` and macOS-only packages via `nix-darwin` if applicable.
- Replace `install.sh` steps with `home-manager` declarations; remove imperative symlinking in favor of `home.file` entries.
- Use `home.activation` hooks sparingly for tasks like ensuring `~/notes` exists.

## Host Definitions
- Define per-machine configs in `flake.nix`, e.g.:
  ```nix
  homeConfigurations."kahvi-macbook" = home-manager.lib.homeManagerConfiguration {
    pkgs = import nixpkgs { system = "aarch64-darwin"; };
    modules = [
      ./modules/common.nix
      ./modules/mac.nix
    ];
  };
  ```
- Linux host would import `./modules/linux.nix`.
- Allow hosts to override variables (paths, work toggles) via `extraSpecialArgs`.

## Migration Process
1. Scaffold flake with minimal `homeConfigurations` pointing to current user; import `home-manager.sharedModules`.
2. Incrementally migrate configs domain-by-domain, verifying generated files with `home-manager switch`.
3. For each migrated file, remove the tracked dotfile or mark it as managed by Nix to avoid divergence.
4. Document manual steps or unavoidable external dependencies in README and within module options.
5. Run `nix flake check` and test host switches until state convergence.

## Open Questions
- How to handle proprietary or work-specific tooling (`/opt/dev`, `cursor`, Sublime Text) that may not be packaged in Nixpkgs?
- Should nginx configs move into a server-specific flake or remain outside home-manager?
- Do macOS GUI apps (Tailscale.app, Chrome AppleScripts) require additional automation beyond file deployment?

