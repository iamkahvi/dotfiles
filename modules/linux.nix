{ pkgs, lib, ... }: {
  xdg.configFile."i3/config".source = ../i3/i3.config;

  home.packages = lib.mkAfter (with pkgs; [
    i3
    feh
    picom
  ]);
}
