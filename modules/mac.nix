{ config, pkgs, lib, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
  xdg.configFile."karabiner/karabiner.json".source = ../karabiner/karabiner.json;

  home.file.".aerospace.toml".source = ../aerospace/.aerospace.toml;
  home.file."Library/Application Support/Hammerspoon/init.lua".source = ../hammerspoon/init.lua;

  home.file."Library/Application Support/iTerm2/DynamicProfiles/Default.json".source = ../iterm2/Default.json;
  home.file."Library/Application Support/iTerm2/DynamicProfiles/Kahvi.json".source = ../iterm2/Kahvi.json;
  home.file."Library/Application Support/iTerm2/DynamicProfiles/Profiles.json".source = ../iterm2/Profiles.json;
  home.file."Library/Preferences/com.googlecode.iterm2.plist".source = ../iterm2/com.googlecode.iterm2.plist;

  # Ghostty and kitty configurations are shared via modules/terminals.nix.

  # Ensure notes workspace exists for Hammerspoon automation.
  home.activation.ensureNotesDirectory =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${homeDir}/notes"
    '';

  # Convenience packages specific to the macOS workstation.
  home.packages = lib.mkAfter (with pkgs; [
    iterm2
    karabiner-elements
    hammerspoon
  ]);
}
