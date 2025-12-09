{ ... }: {
  home.file.".local/bin/tmux-sessionizer" = {
    source = ../tmux/tmux-sessionizer.sh;
    executable = true;
  };

  home.file.".local/bin/tmux-sessions" = {
    source = ../tmux/tmux-sessions.sh;
    executable = true;
  };
}
