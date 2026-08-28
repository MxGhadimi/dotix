{
  self,
  inputs,
  ...
}: let
  inherit (self) nixosModules homeModules;

  hostname = "hikari";

  homeImports = [
    {
      home = {
        username = "masaroshi";
        homeDirectory = "/home/masaroshi";
        stateVersion = "26.05";
      };
      programs.home-manager.enable = true;
    }
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
            extraSpecialArgs = {inherit inputs self hostname;};
            users.masaroshi.imports = homeImports;
          };
        }
      ];
    };
in {
  flake.nixosConfigurations = {
    hikari = mkHikariConfig {};
    hikari-ci = mkHikariConfig {ciBuildable = true;};
  };

  flake.homeConfigurations."masaroshi@${hostname}" = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    extraSpecialArgs = {inherit inputs self hostname;};
    modules = homeImports;
  };
}
