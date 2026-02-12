{
  description = "Declarative Home Manager setup for Kahvi's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, home-manager, darwin, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;

      mkHome = {
        system,
        username,
        homeDirectory,
        extraModules ? [ ],
        extraSpecialArgs ? { },
      }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs { inherit system; };
          extraSpecialArgs =
            extraSpecialArgs
            // {
              inherit inputs;
            };
          modules =
            [
              ./modules/common.nix
              {
                home.username = username;
                home.homeDirectory = homeDirectory;
              }
            ]
            ++ extraModules;
        };
    in
    {
      homeConfigurations = {
        "kahvi-macbook" = mkHome {
          system = "aarch64-darwin";
          username = "iamkahvi";
          homeDirectory = "/Users/iamkahvi";
          extraModules = [
            ./modules/mac.nix
          ];
        };

        "kahvi-linux" = mkHome {
          system = "x86_64-linux";
          username = "kahvi";
          homeDirectory = "/home/kahvi";
          extraModules = [
            ./modules/linux.nix
          ];
        };
      };

      devShells = genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              home-manager
              nixpkgs-fmt
            ];
          };
        });
    };
}
