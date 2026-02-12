{ ... }: {
  xdg.configFile."kitty/kitty.conf".source = ../kitty/kitty.conf;
  xdg.configFile."ghostty/config".source = ../ghostty/config;

  # Keep Hyper configuration co-located even if not currently populated.
  xdg.configFile."hyper".source = ../hyper;
}
