{ config, pkgs, lib, ... }:
{
  imports = [
    ./shell.nix
    ./terminals.nix
    ./tmux.nix
    ./zellij.nix
    ./editors.nix
    ./git.nix
    ./scripts.nix
  ];

  home.stateVersion = lib.mkDefault "24.05";

  home.sessionVariables = {
    DF_HOME = "${config.home.homeDirectory}/dotfiles";
    PAGER = "less";
    EDITOR = "nvim";
    VISUAL = "code";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
  };

  programs.home-manager.enable = true;

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
  };

  programs.zoxide.enable = true;
  programs.bat.enable = true;

  home.packages = with pkgs; [
    bat
    curl
    fd
    fzf
    gh
    git
    go
    gum
    jq
    neovim
    nodejs_20
    python3
    ripgrep
    tmux
    tmuxinator
    tree
    zoxide
    # Editor/runtime tooling available from nixpkgs
    bun
    deno
    lazygit
  ];
}
