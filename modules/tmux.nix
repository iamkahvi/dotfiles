{ pkgs, lib, ... }:
{
  programs.tmux = {
    enable = true;
    clock24 = true;
    terminal = "screen-256color";
    extraConfig = builtins.readFile ../tmux/.tmux.conf;
  };
}
