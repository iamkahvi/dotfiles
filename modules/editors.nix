{ pkgs, lib, ... }:
let
  vscodeSettings = lib.importJSON ../vscode/settings.json;
  vscodeKeybindings = lib.importJSON ../vscode/keybindings.json;
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = true;
    withPython3 = true;
    extraConfig = builtins.readFile ../vim/init.lua;
    plugins = with pkgs.vimPlugins; [
      lazy-nvim
      goyo-vim
      nerdcommenter
      nerdtree
      vim-surround
      rust-vim
      catppuccin-nvim
      telescope-nvim
      plenary-nvim
    ];
  };

  programs.vscode = {
    enable = true;
    userSettings = vscodeSettings;
    keybindings = vscodeKeybindings;
    # Extension resolution via nixpkgs packages; extend as required.
    extensions = with pkgs.vscode-extensions; [
      astro-build.astro-vscode
      esbenp.prettier-vscode
      golang.go
      ms-python.python
      rust-lang.rust-analyzer
      vscodevim.vim
      vscode-icons-team.vscode-icons
      zhuangtongfa.material-theme
      mrmlnc.vscode-scss
    ];
  };
}
