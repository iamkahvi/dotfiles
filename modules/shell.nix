{ pkgs, lib, ... }:
let
  zshWork = lib.replaceStrings
    [ "/Users/kahvipatel" "/Users/kahvi" ]
    [ "$HOME" "$HOME" ]
    (builtins.readFile ../zsh/work.zsh);
in
{
  programs.fish = {
    enable = true;
    interactiveShellInit = builtins.readFile ../fish/config.fish;
    shellInit = ''
      set -gx DF_HOME $HOME/dotfiles
    '';
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initExtra = zshWork;
  };

  # Provide direnv integration for shells commonly used in this setup.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Ensure popular prompt tooling is available irrespective of chosen shell.
  programs.starship = {
    enable = true;
    settings.add_newline = false;
  };
}
