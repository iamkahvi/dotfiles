{ ... }: {
  programs.git = {
    enable = true;
    includes = [
      { path = ../git/.gitconfig; }
    ];
  };
}
