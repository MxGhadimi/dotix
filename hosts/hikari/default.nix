{
  self,
  inputs,
  ...
}: let
  inherit (self) nixosModules homeModules;

  mkHikariConfig = {ciBuildable ? false}:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs self;};
      modules = [
        {custom.ci.buildable = ciBuildable;}

        ./configuration.nix
        ./hardware-configuration.nix
        ./user.nix

        nixosModules.core
        nixosModules.boot
        nixosModules.refind
        {custom.refind.theme = "rEFInd-minimal-rog";}
        nixosModules.cachix-agent

        nixosModules.hardware-audio
        nixosModules.hardware-bluetooth
        nixosModules.hardware-wifi

        nixosModules.niri
        nixosModules.plasma
        {custom.display.defaultSession = "niri";}
        nixosModules.polkit-agent
        nixosModules.shell
        nixosModules.database
        nixosModules.thunar
        nixosModules.throne

        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {inherit inputs self;};
            users.masaroshi.imports = [
              homeModules.git
              homeModules.shell
              homeModules.tmux
              homeModules.ghostty
              homeModules.niri
              homeModules.noctalia
              homeModules.vlc
              homeModules.firefox
              homeModules.zen-browser
              homeModules.neovim
              homeModules.vscode
              homeModules.telegram
              homeModules.vesktop
              homeModules.obsidian
              homeModules.archive
            ];
          };
        }
      ];
    };
in {
  flake.nixosConfigurations = {
    hikari = mkHikariConfig {};
    hikari-ci = mkHikariConfig {ciBuildable = true;};
  };
}
