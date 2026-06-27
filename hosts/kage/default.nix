{
  self,
  inputs,
  ...
}: let
  inherit (self) nixosModules homeModules;

  mkKageConfig = {ciBuildable ? false}:
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
        nixosModules.cachix-agent

        nixosModules.hardware-nvidia
        nixosModules.hardware-audio
        nixosModules.hardware-bluetooth
        nixosModules.hardware-wifi

        nixosModules.llm

        nixosModules.niri
        nixosModules.polkit-agent
        nixosModules.shell
        nixosModules.database
        nixosModules.thunar
        nixosModules.throne
        nixosModules.packettracer

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
    kage = mkKageConfig {};
    kage-ci = mkKageConfig {ciBuildable = true;};
  };
}
