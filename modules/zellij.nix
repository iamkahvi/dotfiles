{ ... }: {
  programs.zellij.enable = true;
  xdg.configFile."zellij/config.kdl".source = ../zellij/config.kdl;
}
